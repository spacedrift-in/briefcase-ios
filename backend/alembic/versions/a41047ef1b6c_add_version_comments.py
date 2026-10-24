"""add append-only version comments

Revision ID: a41047ef1b6c
Revises: 58d67304fb78
Create Date: 2026-10-24 16:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "a41047ef1b6c"
down_revision: Union[str, Sequence[str], None] = "58d67304fb78"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "version_comments",
        sa.Column("id", sa.Uuid(as_uuid=True), primary_key=True, nullable=False),
        sa.Column(
            "version_id",
            sa.Uuid(as_uuid=True),
            sa.ForeignKey("deliverable_versions.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column("actor_subject", sa.String(255), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("idempotency_key", sa.Uuid(as_uuid=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.UniqueConstraint("actor_subject", "idempotency_key", name="uq_version_comment_actor_idempotency"),
    )
    op.create_index("ix_version_comments_version_id", "version_comments", ["version_id"])


def downgrade() -> None:
    op.drop_index("ix_version_comments_version_id", table_name="version_comments")
    op.drop_table("version_comments")
