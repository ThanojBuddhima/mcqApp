from datetime import datetime
from enum import Enum
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class AttemptStatus(str, Enum):
    IN_PROGRESS = "in_progress"
    SUBMITTED = "submitted"
    ABANDONED = "abandoned"


class AnswerSubmit(BaseModel):
    question_id: UUID
    selected_answer: str | None = None
    text_answer: str | None = None


class AnswersBatchSubmit(BaseModel):
    answers: list[AnswerSubmit]


class AttemptAnswerResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    question_id: UUID
    selected_answer: str | None
    text_answer: str | None
    is_correct: bool | None
    marks_awarded: int


class AttemptResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    quiz_id: UUID
    user_id: UUID
    score: int | None
    total_marks: int | None
    duration_seconds: int | None
    status: AttemptStatus
    started_at: datetime
    submitted_at: datetime | None
    answers: list[AttemptAnswerResponse] = []


class AttemptReviewResponse(BaseModel):
    attempt: AttemptResponse
    questions: list[dict]
