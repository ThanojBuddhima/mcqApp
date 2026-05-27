from uuid import UUID

from pydantic import BaseModel, Field


class GenerateMCQsRequest(BaseModel):
    source_text: str = Field(min_length=10)
    count: int = Field(default=5, ge=1, le=20)
    language: str = "sinhala"
    subject: str | None = None


class ExplainAnswerRequest(BaseModel):
    question_text: str
    correct_answer: str
    user_answer: str | None = None
    language: str = "sinhala"


class SummarizeRequest(BaseModel):
    source_text: str = Field(min_length=20)
    language: str = "sinhala"


class FlashcardRequest(BaseModel):
    quiz_id: UUID | None = None
    source_text: str | None = None
    count: int = Field(default=10, ge=1, le=50)


class ChatMessage(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    messages: list[ChatMessage]
    quiz_id: UUID | None = None
    language: str = "sinhala"


class AdjustDifficultyRequest(BaseModel):
    question_text: str
    options: list[str] = Field(default_factory=list)
    target_difficulty: str = "medium"
    language: str = "sinhala"
