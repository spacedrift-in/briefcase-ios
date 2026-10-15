import csv
from io import StringIO
from typing import Any
from uuid import UUID

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Response, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from spacedrift_api.auth import current_identity
from spacedrift_api.db import get_session
from spacedrift_api.models import (
    AuditEvent,
    Deliverable,
    DeliverableVersion,
    Project,
    ProjectMembership,
    ReviewDecision,
    WorkspaceMembership,
)
from spacedrift_api.schemas import AuditRecord, DecisionRequest, DecisionResponse, ProjectSummary, VersionSummary

router = APIRouter(prefix="/api/v1")


def _subject(claims: dict[str, Any]) -> str:
    subject = claims.get("sub")
    if not isinstance(subject, str) or not subject:
        raise HTTPException(status_code=401, detail="invalid_access_token")
    return subject


def _member_project(session: Session, project_id: UUID, subject: str) -> tuple[Project, str]:
    row = session.execute(
        select(Project, ProjectMembership.role)
        .join(ProjectMembership, ProjectMembership.project_id == Project.id)
        .join(WorkspaceMembership, WorkspaceMembership.workspace_id == Project.workspace_id)
        .where(
            Project.id == project_id,
            ProjectMembership.subject == subject,
            ProjectMembership.active.is_(True),
            WorkspaceMembership.subject == subject,
            WorkspaceMembership.active.is_(True),
        )
    ).first()
    if row is None:
        raise HTTPException(status_code=404, detail="project_not_found")
    return row[0], row[1]


@router.get("/projects", response_model=list[ProjectSummary])
def list_projects(
    claims: dict[str, Any] = Depends(current_identity),
    session: Session = Depends(get_session),
) -> list[ProjectSummary]:
    subject = _subject(claims)
    rows = session.execute(
        select(Project)
        .join(ProjectMembership, ProjectMembership.project_id == Project.id)
        .join(WorkspaceMembership, WorkspaceMembership.workspace_id == Project.workspace_id)
        .where(
            ProjectMembership.subject == subject,
            ProjectMembership.active.is_(True),
            WorkspaceMembership.subject == subject,
            WorkspaceMembership.active.is_(True),
        )
        .order_by(Project.name)
    ).scalars()
    return [ProjectSummary(id=p.id, name=p.name, summary=p.summary) for p in rows]


@router.get("/projects/{project_id}/timeline", response_model=list[VersionSummary])
def project_timeline(
    project_id: UUID,
    claims: dict[str, Any] = Depends(current_identity),
    session: Session = Depends(get_session),
) -> list[VersionSummary]:
    _member_project(session, project_id, _subject(claims))
    rows = session.execute(
        select(DeliverableVersion, ReviewDecision.action)
        .join(Deliverable, Deliverable.id == DeliverableVersion.deliverable_id)
        .outerjoin(ReviewDecision, ReviewDecision.version_id == DeliverableVersion.id)
        .where(Deliverable.project_id == project_id)
        .order_by(DeliverableVersion.created_at.desc())
    ).all()
    return [
        VersionSummary(
            id=version.id,
            deliverable_id=version.deliverable_id,
            version_number=version.version_number,
            media_type=version.media_type,
            byte_size=version.byte_size,
            author_subject=version.author_subject,
            created_at=version.created_at,
            review_status={
                "approve": "approved",
                "request_changes": "changes_requested",
            }.get(action, "awaiting_review"),
        )
        for version, action in rows
    ]


@router.post(
    "/versions/{version_id}/decisions",
    response_model=DecisionResponse,
    status_code=status.HTTP_201_CREATED,
)
def decide_version(
    version_id: UUID,
    request: DecisionRequest,
    claims: dict[str, Any] = Depends(current_identity),
    session: Session = Depends(get_session),
    idempotency_key: UUID = Header(alias="Idempotency-Key"),
) -> ReviewDecision:
    subject = _subject(claims)
    context = session.execute(
        select(DeliverableVersion, Deliverable.project_id)
        .join(Deliverable, Deliverable.id == DeliverableVersion.deliverable_id)
        .where(DeliverableVersion.id == version_id)
    ).first()
    if context is None:
        raise HTTPException(status_code=404, detail="version_not_found")
    version, project_id = context
    try:
        project, role = _member_project(session, project_id, subject)
    except HTTPException as exc:
        if exc.status_code == 404:
            # Use one denial shape so callers cannot probe for restricted version IDs.
            raise HTTPException(status_code=404, detail="version_not_found") from exc
        raise
    if role != "client_reviewer":
        raise HTTPException(status_code=403, detail="decision_not_permitted")

    normalized_comment = request.comment.strip() if request.comment is not None else None
    if request.action == "request_changes" and not normalized_comment:
        raise HTTPException(status_code=422, detail="change_request_needs_comment")

    prior_key = session.scalar(
        select(ReviewDecision).where(
            ReviewDecision.actor_subject == subject,
            ReviewDecision.idempotency_key == idempotency_key,
        )
    )
    if prior_key is not None:
        same_request = (
            prior_key.version_id == version_id
            and prior_key.action == request.action
            and prior_key.comment == normalized_comment
        )
        if same_request:
            return prior_key
        raise HTTPException(status_code=409, detail="idempotency_key_reused")

    locked_version = session.scalar(
        select(DeliverableVersion).where(DeliverableVersion.id == version_id).with_for_update()
    )
    if locked_version is None:
        raise HTTPException(status_code=404, detail="version_not_found")
    existing = session.scalar(select(ReviewDecision).where(ReviewDecision.version_id == version_id))
    if existing is not None:
        raise HTTPException(status_code=409, detail="version_already_decided")

    decision = ReviewDecision(
        version_id=version_id,
        actor_subject=subject,
        action=request.action,
        comment=normalized_comment,
        idempotency_key=idempotency_key,
    )
    try:
        session.add(decision)
        session.flush()
        session.add(
            AuditEvent(
                workspace_id=project.workspace_id,
                project_id=project.id,
                version_id=version.id,
                decision_id=decision.id,
                actor_subject=subject,
                event_type=request.action,
            )
        )
        session.commit()
    except IntegrityError as exc:
        session.rollback()
        raise HTTPException(status_code=409, detail="version_already_decided") from exc
    session.refresh(decision)
    return decision


@router.get("/projects/{project_id}/audit-export")
def export_audit(
    project_id: UUID,
    format: str = Query(default="json", pattern="^(json|csv)$"),
    claims: dict[str, Any] = Depends(current_identity),
    session: Session = Depends(get_session),
) -> Any:
    project, _ = _member_project(session, project_id, _subject(claims))
    rows = session.execute(
        select(AuditEvent, ReviewDecision)
        .join(ReviewDecision, ReviewDecision.id == AuditEvent.decision_id)
        .where(AuditEvent.workspace_id == project.workspace_id, AuditEvent.project_id == project.id)
        .order_by(AuditEvent.created_at, AuditEvent.id)
    ).all()
    records = [
        AuditRecord(
            event_id=event.id,
            decision_id=decision.id,
            version_id=event.version_id,
            actor_subject=event.actor_subject,
            action=decision.action,
            comment=decision.comment,
            created_at=event.created_at,
        )
        for event, decision in rows
    ]
    if format == "json":
        return records

    output = StringIO()
    writer = csv.writer(output)
    writer.writerow(["event_id", "decision_id", "version_id", "actor_subject", "action", "comment", "created_at"])
    for record in records:
        comment = record.comment or ""
        values = [record.event_id, record.decision_id, record.version_id, record.actor_subject, record.action, comment, record.created_at.isoformat()]
        values = [
            "'" + value if isinstance(value, str) and value.lstrip(" \t\r\n").startswith(("=", "+", "-", "@")) else value
            for value in values
        ]
        writer.writerow(
            values
        )
    return Response(
        content=output.getvalue(),
        media_type="text/csv",
        headers={"Content-Disposition": f'attachment; filename="project-{project.id}-audit.csv"'},
    )
