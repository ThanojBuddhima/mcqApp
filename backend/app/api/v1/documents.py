from uuid import UUID

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.core.deps import get_current_user
from app.models import User
from app.schemas.document import DocumentJobResponse, DocumentPreviewResponse
from app.services.document import document_service
from app.services.quiz import quiz_service
from app.workers.tasks import process_document_task

router = APIRouter()


@router.post("/upload", response_model=DocumentJobResponse, status_code=status.HTTP_201_CREATED)
async def upload_document(
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    content = await file.read()
    max_bytes = settings.max_upload_size_mb * 1024 * 1024
    if len(content) > max_bytes:
        raise HTTPException(status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, detail="File too large")

    content_type = file.content_type or "application/octet-stream"
    try:
        job = await document_service.create_upload_job(
            db, user.id, file.filename or "upload", content_type, content
        )
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    process_document_task.delay(str(job.id))
    return job


@router.get("/jobs/{job_id}", response_model=DocumentJobResponse)
async def get_job_status(
    job_id: UUID,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    job = await document_service.get_job(db, job_id, user.id)
    if job is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Job not found")
    return job


@router.get("/jobs/{job_id}/preview", response_model=DocumentPreviewResponse)
async def preview_job(
    job_id: UUID,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    job = await document_service.get_job(db, job_id, user.id)
    if job is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Job not found")

    quiz_preview = None
    if job.result_quiz_id:
        quiz = await quiz_service.get_by_id(db, job.result_quiz_id)
        if quiz:
            quiz_preview = quiz.content
    return DocumentPreviewResponse(job=job, quiz_preview=quiz_preview)


@router.post("/jobs/{job_id}/confirm", response_model=DocumentJobResponse)
async def confirm_job(
    job_id: UUID,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    job = await document_service.get_job(db, job_id, user.id)
    if job is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Job not found")
    if not job.result_quiz_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No quiz generated yet")
    return job
