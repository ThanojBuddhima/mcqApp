from datetime import datetime
from enum import Enum
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class Medium(str, Enum):
    SINHALA = "sinhala"
    ENGLISH = "english"
    TAMIL = "tamil"


class SubjectResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name_en: str
    name_si: str | None
    grade_levels: list


class PastPaperCreate(BaseModel):
    quiz_id: UUID
    subject_id: UUID
    grade: str
    medium: Medium
    year: int
    exam_type: str
    answer_scheme_url: str | None = None
    original_pdf_url: str | None = None


class PastPaperResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    quiz_id: UUID
    subject_id: UUID
    grade: str
    medium: Medium
    year: int
    exam_type: str
    answer_scheme_url: str | None
    original_pdf_url: str | None
    quiz_title: str | None = None
    subject_name: str | None = None


class PastPaperFilter(BaseModel):
    grade: str | None = None
    subject_id: UUID | None = None
    medium: Medium | None = None
    year: int | None = None
    exam_type: str | None = None
    skip: int = 0
    limit: int = 20
