from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class ProjectSummary(BaseModel):
    id: UUID
    name: str
    summary: str


class VersionSummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    deliverable_id: UUID
    version_number: int
    media_type: str
    byte_size: int
    author_subject: str
    created_at: datetime
    review_status: str


class DecisionRequest(BaseModel):
    action: Literal["request_changes", "approve"]
    comment: str | None = Field(default=None, max_length=4000)


class DecisionResponse(BaseModel):
    id: UUID
    version_id: UUID
    actor_subject: str
    action: str
    comment: str | None
    created_at: datetime


class CommentRequest(BaseModel):
    body: str = Field(min_length=1, max_length=4000)


class CommentResponse(BaseModel):
    id: UUID
    version_id: UUID
    actor_subject: str
    body: str
    created_at: datetime


class AuditRecord(BaseModel):
    event_id: UUID
    decision_id: UUID | None
    version_id: UUID
    actor_subject: str
    action: str
    comment: str | None
    created_at: datetime
