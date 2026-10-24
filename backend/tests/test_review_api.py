import asyncio
from collections.abc import Iterator
from uuid import UUID, uuid4

import httpx
import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from spacedrift_api.auth import current_identity
from spacedrift_api.db import get_session
from spacedrift_api.main import app
from spacedrift_api.models import (
    AuditEvent,
    Base,
    Deliverable,
    DeliverableVersion,
    Project,
    ProjectMembership,
    ReviewDecision,
    Workspace,
    WorkspaceMembership,
    VersionComment,
)


@pytest.fixture
def review_api() -> Iterator[tuple[sessionmaker[Session], UUID, UUID, UUID, UUID, UUID]]:
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    factory = sessionmaker(bind=engine, expire_on_commit=False)
    with factory() as session:
        workspace = Workspace(name="Synthetic Workspace Alpha")
        other_workspace = Workspace(name="Synthetic Workspace Beta")
        session.add_all([workspace, other_workspace])
        session.flush()
        session.add_all(
            [
                WorkspaceMembership(workspace_id=workspace.id, subject="client-a", active=True),
                WorkspaceMembership(workspace_id=workspace.id, subject="consultant-a", active=True),
                WorkspaceMembership(workspace_id=other_workspace.id, subject="other-user", active=True),
            ]
        )
        project = Project(workspace_id=workspace.id, name="Demo Project", summary="Synthetic only")
        restricted = Project(workspace_id=other_workspace.id, name="Restricted Project", summary="Synthetic only")
        session.add_all([project, restricted])
        session.flush()
        session.add_all(
            [
                ProjectMembership(project_id=project.id, subject="client-a", role="client_reviewer"),
                ProjectMembership(project_id=project.id, subject="consultant-a", role="consultant"),
            ]
        )
        deliverable = Deliverable(project_id=project.id, title="Brand concept")
        restricted_deliverable = Deliverable(project_id=restricted.id, title="Secret concept")
        session.add_all([deliverable, restricted_deliverable])
        session.flush()
        version_one = DeliverableVersion(
            deliverable_id=deliverable.id,
            version_number=1,
            storage_key="private/demo/v1.pdf",
            media_type="application/pdf",
            byte_size=128,
            author_subject="consultant-a",
        )
        version_two = DeliverableVersion(
            deliverable_id=deliverable.id,
            version_number=2,
            storage_key="private/demo/v2.pdf",
            media_type="application/pdf",
            byte_size=256,
            author_subject="consultant-a",
        )
        restricted_version = DeliverableVersion(
            deliverable_id=restricted_deliverable.id,
            version_number=1,
            storage_key="private/restricted/v1.pdf",
            media_type="application/pdf",
            byte_size=512,
            author_subject="other-user",
        )
        session.add_all([version_one, version_two, restricted_version])
        session.commit()
        ids = (project.id, version_one.id, version_two.id, restricted.id, restricted_version.id)

    principal = {"sub": "client-a"}

    def identity_override() -> dict[str, str]:
        return principal

    def session_override() -> Iterator[Session]:
        with factory() as session:
            yield session

    app.dependency_overrides[current_identity] = identity_override
    app.dependency_overrides[get_session] = session_override
    try:
        yield factory, ids[0], ids[1], ids[2], ids[3], ids[4]
    finally:
        app.dependency_overrides.clear()
        Base.metadata.drop_all(engine)
        engine.dispose()


def api_call(method: str, path: str, **kwargs: object) -> httpx.Response:
    async def send() -> httpx.Response:
        transport = httpx.ASGITransport(app=app)
        async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
            return await client.request(method, path, **kwargs)

    return asyncio.run(send())


def test_project_listing_and_timeline_are_scoped_to_membership(
    review_api: tuple[sessionmaker, UUID, UUID, UUID, UUID, UUID],
) -> None:
    _, _, _, _, restricted_project_id, restricted_version_id = review_api
    project_response = api_call("GET", "/api/v1/projects")
    assert project_response.status_code == 200
    assert [item["name"] for item in project_response.json()] == ["Demo Project"]

    principal = app.dependency_overrides[current_identity]()
    app.dependency_overrides[current_identity] = lambda: {**principal, "sub": "outsider"}
    foreign = api_call("GET", f"/api/v1/projects/{restricted_project_id}/timeline")
    assert foreign.status_code == 404
    assert foreign.json()["detail"] == "project_not_found"
    foreign_export = api_call("GET", f"/api/v1/projects/{restricted_project_id}/audit-export")
    assert foreign_export.status_code == 404
    assert foreign_export.json()["detail"] == "project_not_found"
    foreign_version = api_call(
        "POST",
        f"/api/v1/versions/{restricted_version_id}/decisions",
        json={"action": "approve"},
        headers={"Idempotency-Key": str(uuid4())},
    )
    assert foreign_version.status_code == 404
    assert foreign_version.json()["detail"] == "version_not_found"


def test_active_workspace_membership_is_required_even_with_project_membership(
    review_api: tuple[sessionmaker, UUID, UUID, UUID, UUID, UUID],
) -> None:
    factory, _, _, _, _, _ = review_api
    with factory() as session:
        membership = session.scalar(
            select(WorkspaceMembership).where(WorkspaceMembership.subject == "client-a")
        )
        assert membership is not None
        membership.active = False
        session.commit()
    response = api_call("GET", "/api/v1/projects")
    assert response.status_code == 200
    assert response.json() == []


def test_project_and_version_detail_are_membership_scoped(
    review_api: tuple[sessionmaker, UUID, UUID, UUID, UUID, UUID],
) -> None:
    _, project_id, version_id, _, restricted_project_id, restricted_version_id = review_api

    project = api_call("GET", f"/api/v1/projects/{project_id}")
    assert project.status_code == 200
    assert project.json()["name"] == "Demo Project"

    version = api_call("GET", f"/api/v1/versions/{version_id}")
    assert version.status_code == 200
    assert version.json()["id"] == str(version_id)
    assert version.json()["review_status"] == "awaiting_review"

    outsider = api_call("GET", f"/api/v1/projects/{restricted_project_id}")
    assert outsider.status_code == 404
    hidden_version = api_call("GET", f"/api/v1/versions/{restricted_version_id}")
    assert hidden_version.status_code == 404
    assert hidden_version.json()["detail"] == "version_not_found"


def test_version_comments_are_membership_scoped_and_idempotent(
    review_api: tuple[sessionmaker, UUID, UUID, UUID, UUID, UUID],
) -> None:
    factory, project_id, version_id, _, _, restricted_version_id = review_api
    key = uuid4()
    headers = {"Idempotency-Key": str(key)}
    request = {"body": "  Please update the cover image.  "}

    first = api_call("POST", f"/api/v1/versions/{version_id}/comments", json=request, headers=headers)
    retry = api_call("POST", f"/api/v1/versions/{version_id}/comments", json=request, headers=headers)
    assert first.status_code == 201
    assert retry.status_code == 201
    assert first.json()["id"] == retry.json()["id"]
    assert first.json()["body"] == "Please update the cover image."

    listed = api_call("GET", f"/api/v1/versions/{version_id}/comments")
    assert listed.status_code == 200
    assert len(listed.json()) == 1
    with factory() as session:
        assert len(session.scalars(select(VersionComment)).all()) == 1

    exported_comments = api_call("GET", f"/api/v1/projects/{project_id}/audit-export?format=json")
    assert exported_comments.status_code == 200
    assert exported_comments.json()[0]["action"] == "comment"
    assert exported_comments.json()[0]["decision_id"] is None

    reused_key = api_call(
        "POST",
        f"/api/v1/versions/{version_id}/comments",
        json={"body": "A different comment"},
        headers=headers,
    )
    assert reused_key.status_code == 409

    forbidden = api_call(
        "POST",
        f"/api/v1/versions/{restricted_version_id}/comments",
        json={"body": "Should not leak"},
        headers={"Idempotency-Key": str(uuid4())},
    )
    assert forbidden.status_code == 404
    hidden_comments = api_call("GET", f"/api/v1/versions/{restricted_version_id}/comments")
    assert hidden_comments.status_code == 404

    app.dependency_overrides[current_identity] = lambda: {"sub": "consultant-a"}
    consultant_comment = api_call(
        "POST",
        f"/api/v1/versions/{version_id}/comments",
        json={"body": "Reviewer feedback"},
        headers={"Idempotency-Key": str(uuid4())},
    )
    assert consultant_comment.status_code == 403
    assert consultant_comment.json()["detail"] == "comment_not_permitted"


def test_version_comment_rejects_blank_body(
    review_api: tuple[sessionmaker, UUID, UUID, UUID, UUID, UUID],
) -> None:
    _, _, version_id, _, _, _ = review_api
    response = api_call(
        "POST",
        f"/api/v1/versions/{version_id}/comments",
        json={"body": "  "},
        headers={"Idempotency-Key": str(uuid4())},
    )
    assert response.status_code == 422


def test_approval_is_persisted_for_exact_version_with_audit_and_idempotent_retry(
    review_api: tuple[sessionmaker, UUID, UUID, UUID, UUID, UUID],
) -> None:
    factory, project_id, version_one, version_two, _, _ = review_api
    key = uuid4()
    request = {"action": "approve", "comment": "=1+1"}
    headers = {"Idempotency-Key": str(key)}
    first = api_call("POST", f"/api/v1/versions/{version_one}/decisions", json=request, headers=headers)
    retry = api_call("POST", f"/api/v1/versions/{version_one}/decisions", json=request, headers=headers)

    assert first.status_code == 201
    assert retry.status_code == 201
    assert retry.json()["id"] == first.json()["id"]
    assert first.json()["version_id"] == str(version_one)
    assert first.json()["actor_subject"] == "client-a"
    with factory() as session:
        decisions = session.scalars(select(ReviewDecision)).all()
        events = session.scalars(select(AuditEvent)).all()
        assert len(decisions) == 1
        assert len(events) == 1
        assert events[0].decision_id == decisions[0].id
        assert events[0].version_id == version_one
        assert events[0].actor_subject == "client-a"

    timeline = api_call("GET", f"/api/v1/projects/{project_id}/timeline")
    assert timeline.status_code == 200, timeline.text
    states = {row["id"]: row["review_status"] for row in timeline.json()}
    assert states[str(version_one)] == "approved"
    assert states[str(version_two)] == "awaiting_review"

    exported = api_call("GET", f"/api/v1/projects/{project_id}/audit-export?format=json")
    assert exported.status_code == 200
    assert len(exported.json()) == 1
    assert exported.json()[0]["version_id"] == str(version_one)
    assert exported.json()[0]["actor_subject"] == "client-a"
    csv_export = api_call("GET", f"/api/v1/projects/{project_id}/audit-export?format=csv")
    assert csv_export.status_code == 200
    assert csv_export.headers["content-type"].startswith("text/csv")
    assert "'=1+1" in csv_export.text


def test_change_request_requires_comment_and_consultant_cannot_decide(
    review_api: tuple[sessionmaker, UUID, UUID, UUID, UUID, UUID],
) -> None:
    _, _, version_one, _, _, _ = review_api
    empty = api_call(
        "POST",
        f"/api/v1/versions/{version_one}/decisions",
        json={"action": "request_changes", "comment": "  "},
        headers={"Idempotency-Key": str(uuid4())},
    )
    assert empty.status_code == 422

    app.dependency_overrides[current_identity] = lambda: {"sub": "consultant-a"}
    denied = api_call(
        "POST",
        f"/api/v1/versions/{version_one}/decisions",
        json={"action": "approve"},
        headers={"Idempotency-Key": str(uuid4())},
    )
    assert denied.status_code == 403


def test_request_changes_is_a_distinct_terminal_version_decision(
    review_api: tuple[sessionmaker, UUID, UUID, UUID, UUID, UUID],
) -> None:
    _, project_id, version_one, _, _, _ = review_api
    key = uuid4()
    response = api_call(
        "POST",
        f"/api/v1/versions/{version_one}/decisions",
        json={"action": "request_changes", "comment": "Please replace the title slide."},
        headers={"Idempotency-Key": str(key)},
    )
    assert response.status_code == 201
    assert response.json()["action"] == "request_changes"
    assert response.json()["comment"] == "Please replace the title slide."

    conflicting_decision = api_call(
        "POST",
        f"/api/v1/versions/{version_one}/decisions",
        json={"action": "approve"},
        headers={"Idempotency-Key": str(uuid4())},
    )
    assert conflicting_decision.status_code == 409
    timeline = api_call("GET", f"/api/v1/projects/{project_id}/timeline")
    assert timeline.status_code == 200, timeline.text
    status_by_version = {row["id"]: row["review_status"] for row in timeline.json()}
    assert status_by_version[str(version_one)] == "changes_requested"
