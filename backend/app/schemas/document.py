from datetime import datetime
from enum import Enum
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class DocumentJobStatus(str, Enum):
    PENDING = "pending"
    PREPROCESSING = "preprocessing"
    LAYOUT = "layout"
    OCR = "ocr"
    SEGMENTATION = "segmentation"
    AI_PARSE = "ai_parse"
    COMPLETED = "completed"
    FAILED = "failed"


class DocumentJobResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    status: DocumentJobStatus
    source_filename: str
    page_count: int
    progress_percent: int
    error_log: str | None
    result_quiz_id: UUID | None
    created_at: datetime
    updated_at: datetime


class DocumentPreviewResponse(BaseModel):
    job: DocumentJobResponse
    quiz_preview: dict | None


class DocumentBlockResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    block_type: str
    bbox: list
    ocr_text: str | None
    ocr_lang: str | None
    confidence: float | None
    needs_review: bool
    figure_url: str | None


class DocumentPageResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    page_index: int
    image_url: str
    layout_json: dict
    blocks: list[DocumentBlockResponse] = []
