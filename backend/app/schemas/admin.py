from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict

from app.schemas.auth import UserRole


class AdminOverview(BaseModel):
    total_users: int
    users_by_role: dict[str, int]
    total_quizzes: int
    quizzes_by_status: dict[str, int]
    total_attempts: int
    submitted_attempts: int
    total_document_jobs: int
    document_jobs_by_status: dict[str, int]
    total_classes: int
    total_past_papers: int
    active_users: int


class ActivityItem(BaseModel):
    id: str
    type: str
    title: str
    subtitle: str | None = None
    status: str | None = None
    created_at: datetime


class AdminOverviewResponse(BaseModel):
    stats: AdminOverview
    recent_activity: list[ActivityItem]


class AdminUserItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    email: str
    display_name: str
    grade: str | None = None
    role: UserRole
    is_active: bool
    created_at: datetime


class AdminUserListResponse(BaseModel):
    items: list[AdminUserItem]
    total: int


class AdminUserUpdate(BaseModel):
    role: UserRole | None = None
    is_active: bool | None = None


class AdminDocumentJobItem(BaseModel):
    id: UUID
    user_id: UUID
    user_email: str | None = None
    user_name: str | None = None
    status: str
    source_filename: str
    progress_percent: int
    error_log: str | None = None
    result_quiz_id: UUID | None = None
    created_at: datetime
    updated_at: datetime


class AdminQuizItem(BaseModel):
    id: UUID
    title: str
    status: str
    visibility: str
    total_marks: int
    creator_id: UUID
    creator_name: str | None = None
    creator_email: str | None = None
    created_at: datetime


class AdminAttemptItem(BaseModel):
    id: UUID
    quiz_id: UUID
    quiz_title: str | None = None
    user_id: UUID
    user_name: str | None = None
    user_email: str | None = None
    score: int | None = None
    total_marks: int | None = None
    status: str
    submitted_at: datetime | None = None
    started_at: datetime
