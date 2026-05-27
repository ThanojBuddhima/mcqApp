from datetime import datetime
from enum import Enum
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class QuestionType(str, Enum):
    MCQ = "mcq"
    STRUCTURED = "structured"
    TRUE_FALSE = "true_false"


class QuizStatus(str, Enum):
    DRAFT = "draft"
    PUBLISHED = "published"
    ARCHIVED = "archived"


class QuizVisibility(str, Enum):
    PRIVATE = "private"
    PUBLIC = "public"
    CLASS_ONLY = "class_only"


class QuestionOptionCreate(BaseModel):
    label: str
    option_text: str | None = None
    option_image_url: str | None = None
    is_correct: bool = False


class QuestionOptionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    label: str
    option_text: str | None
    option_image_url: str | None
    is_correct: bool


class QuestionCreate(BaseModel):
    order_index: int = 0
    type: QuestionType = QuestionType.MCQ
    question_text: str
    question_image_url: str | None = None
    layout_refs: dict = Field(default_factory=dict)
    marks: int = 1
    explanation: str | None = None
    difficulty: str | None = None
    correct_answer: str | None = None
    options: list[QuestionOptionCreate] = Field(default_factory=list)


class QuestionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    order_index: int
    type: QuestionType
    question_text: str
    question_image_url: str | None
    layout_refs: dict
    marks: int
    explanation: str | None
    difficulty: str | None
    correct_answer: str | None
    options: list[QuestionOptionResponse] = []


class QuizCreate(BaseModel):
    title: str = Field(min_length=1, max_length=500)
    description: str | None = None
    time_limit_minutes: int | None = None
    visibility: QuizVisibility = QuizVisibility.PRIVATE
    metadata_extra: dict = Field(default_factory=dict)
    questions: list[QuestionCreate] = Field(default_factory=list)


class QuizUpdate(BaseModel):
    title: str | None = None
    description: str | None = None
    time_limit_minutes: int | None = None
    visibility: QuizVisibility | None = None
    status: QuizStatus | None = None
    metadata_extra: dict | None = None
    questions: list[QuestionCreate] | None = None


class QuizResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    creator_id: UUID
    title: str
    description: str | None
    status: QuizStatus
    visibility: QuizVisibility
    content: dict
    time_limit_minutes: int | None
    total_marks: int
    share_code: str | None
    price_lkr: float | None
    metadata_extra: dict
    created_at: datetime
    updated_at: datetime
    questions: list[QuestionResponse] = []


class QuizListResponse(BaseModel):
    items: list[QuizResponse]
    total: int


class ShareCodeResponse(BaseModel):
    share_code: str
    share_url: str
