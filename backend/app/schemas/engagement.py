from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class ClassCreate(BaseModel):
    name: str = Field(min_length=2, max_length=255)
    description: str | None = None


class ClassResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    tutor_id: UUID
    name: str
    description: str | None
    enrollment_code: str
    created_at: datetime


class EnrollRequest(BaseModel):
    enrollment_code: str = Field(min_length=4, max_length=12)


class EnrollmentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    class_id: UUID
    student_id: UUID
    enrolled_at: datetime


class LeaderboardEntry(BaseModel):
    user_id: str
    score: int
    rank: int
    display_name: str | None = None


class StudentAnalytics(BaseModel):
    total_attempts: int
    avg_score: float
    avg_percentage: float
    recent_attempts: list[dict]
