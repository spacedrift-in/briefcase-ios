"""initial workflow schema

Revision ID: 58d67304fb78
Revises:
Create Date: 2026-10-15 20:49:52.768723

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '58d67304fb78'
down_revision: Union[str, Sequence[str], None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "workspaces",
        sa.Column("id", sa.Uuid(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("name", sa.String(200), nullable=False),
    )
    op.create_table(
        "workspace_memberships",
        sa.Column("id", sa.Uuid(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("workspace_id", sa.Uuid(as_uuid=True), sa.ForeignKey("workspaces.id", ondelete="CASCADE"), nullable=False),
        sa.Column("subject", sa.String(255), nullable=False),
        sa.Column("active", sa.Boolean(), nullable=False),
        sa.UniqueConstraint("workspace_id", "subject", name="uq_workspace_member_subject"),
    )
    op.create_index("ix_workspace_memberships_workspace_id", "workspace_memberships", ["workspace_id"])
    op.create_index("ix_workspace_memberships_subject", "workspace_memberships", ["subject"])
    op.create_table(
        "projects",
        sa.Column("id", sa.Uuid(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("workspace_id", sa.Uuid(as_uuid=True), sa.ForeignKey("workspaces.id", ondelete="CASCADE"), nullable=False),
        sa.Column("name", sa.String(200), nullable=False),
        sa.Column("summary", sa.Text(), nullable=False),
    )
    op.create_index("ix_projects_workspace_id", "projects", ["workspace_id"])
    op.create_table(
        "project_memberships",
        sa.Column("id", sa.Uuid(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("project_id", sa.Uuid(as_uuid=True), sa.ForeignKey("projects.id", ondelete="CASCADE"), nullable=False),
        sa.Column("subject", sa.String(255), nullable=False),
        sa.Column("role", sa.String(40), nullable=False),
        sa.Column("active", sa.Boolean(), nullable=False),
        sa.UniqueConstraint("project_id", "subject", name="uq_project_member_subject"),
    )
    op.create_index("ix_project_memberships_project_id", "project_memberships", ["project_id"])
    op.create_index("ix_project_memberships_subject", "project_memberships", ["subject"])
    op.create_table(
        "deliverables",
        sa.Column("id", sa.Uuid(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("project_id", sa.Uuid(as_uuid=True), sa.ForeignKey("projects.id", ondelete="CASCADE"), nullable=False),
        sa.Column("title", sa.String(200), nullable=False),
    )
    op.create_index("ix_deliverables_project_id", "deliverables", ["project_id"])
    op.create_table(
        "deliverable_versions",
        sa.Column("id", sa.Uuid(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("deliverable_id", sa.Uuid(as_uuid=True), sa.ForeignKey("deliverables.id", ondelete="CASCADE"), nullable=False),
        sa.Column("version_number", sa.Integer(), nullable=False),
        sa.Column("storage_key", sa.String(500), nullable=False),
        sa.Column("media_type", sa.String(100), nullable=False),
        sa.Column("byte_size", sa.Integer(), nullable=False),
        sa.Column("author_subject", sa.String(255), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.UniqueConstraint("deliverable_id", "version_number", name="uq_deliverable_version_number"),
    )
    op.create_index("ix_deliverable_versions_deliverable_id", "deliverable_versions", ["deliverable_id"])
    op.create_table(
        "review_decisions",
        sa.Column("id", sa.Uuid(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("version_id", sa.Uuid(as_uuid=True), sa.ForeignKey("deliverable_versions.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("actor_subject", sa.String(255), nullable=False),
        sa.Column("action", sa.String(40), nullable=False),
        sa.Column("comment", sa.Text(), nullable=True),
        sa.Column("idempotency_key", sa.Uuid(as_uuid=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.UniqueConstraint("version_id", name="uq_review_decision_version"),
        sa.UniqueConstraint("actor_subject", "idempotency_key", name="uq_decision_actor_idempotency"),
    )
    op.create_index("ix_review_decisions_version_id", "review_decisions", ["version_id"])
    op.create_table(
        "audit_events",
        sa.Column("id", sa.Uuid(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("workspace_id", sa.Uuid(as_uuid=True), sa.ForeignKey("workspaces.id", ondelete="CASCADE"), nullable=False),
        sa.Column("project_id", sa.Uuid(as_uuid=True), sa.ForeignKey("projects.id", ondelete="CASCADE"), nullable=False),
        sa.Column("version_id", sa.Uuid(as_uuid=True), sa.ForeignKey("deliverable_versions.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("decision_id", sa.Uuid(as_uuid=True), sa.ForeignKey("review_decisions.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("actor_subject", sa.String(255), nullable=False),
        sa.Column("event_type", sa.String(40), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.UniqueConstraint("decision_id"),
    )
    op.create_index("ix_audit_events_workspace_id", "audit_events", ["workspace_id"])
    op.create_index("ix_audit_events_project_id", "audit_events", ["project_id"])
    op.create_index("ix_audit_events_version_id", "audit_events", ["version_id"])


def downgrade() -> None:
    op.drop_index("ix_audit_events_version_id", table_name="audit_events")
    op.drop_index("ix_audit_events_project_id", table_name="audit_events")
    op.drop_index("ix_audit_events_workspace_id", table_name="audit_events")
    op.drop_table("audit_events")
    op.drop_index("ix_review_decisions_version_id", table_name="review_decisions")
    op.drop_table("review_decisions")
    op.drop_index("ix_deliverable_versions_deliverable_id", table_name="deliverable_versions")
    op.drop_table("deliverable_versions")
    op.drop_index("ix_deliverables_project_id", table_name="deliverables")
    op.drop_table("deliverables")
    op.drop_index("ix_project_memberships_subject", table_name="project_memberships")
    op.drop_index("ix_project_memberships_project_id", table_name="project_memberships")
    op.drop_table("project_memberships")
    op.drop_index("ix_projects_workspace_id", table_name="projects")
    op.drop_table("projects")
    op.drop_index("ix_workspace_memberships_subject", table_name="workspace_memberships")
    op.drop_index("ix_workspace_memberships_workspace_id", table_name="workspace_memberships")
    op.drop_table("workspace_memberships")
    op.drop_table("workspaces")
