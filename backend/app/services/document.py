from uuid import UUID, uuid4

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import DocumentJob, DocumentJobStatus
from app.services.storage import storage_service


class DocumentService:
    ALLOWED_TYPES = {
        "image/jpeg": "jpg",
        "image/png": "png",
        "image/webp": "webp",
        "application/pdf": "pdf",
    }

    async def create_upload_job(
        self,
        db: AsyncSession,
        user_id: UUID,
        filename: str,
        content_type: str,
        file_bytes: bytes,
    ) -> DocumentJob:
        if content_type not in self.ALLOWED_TYPES:
            raise ValueError(f"Unsupported file type: {content_type}")

        ext = self.ALLOWED_TYPES[content_type]
        key = f"uploads/{user_id}/{uuid4()}.{ext}"
        url = storage_service.upload_bytes(key, file_bytes, content_type)

        job = DocumentJob(
            user_id=user_id,
            source_file_url=url,
            source_filename=filename,
            status=DocumentJobStatus.PENDING,
        )
        db.add(job)
        await db.flush()
        return job

    async def get_job(self, db: AsyncSession, job_id: UUID, user_id: UUID | None = None) -> DocumentJob | None:
        query = select(DocumentJob).where(DocumentJob.id == job_id)
        if user_id:
            query = query.where(DocumentJob.user_id == user_id)
        result = await db.execute(query)
        return result.scalar_one_or_none()

    async def update_job_status(
        self,
        db: AsyncSession,
        job: DocumentJob,
        status: DocumentJobStatus,
        progress: int,
        error: str | None = None,
        result_quiz_id: UUID | None = None,
    ) -> DocumentJob:
        job.status = status
        job.progress_percent = progress
        if error:
            job.error_log = error
        if result_quiz_id:
            job.result_quiz_id = result_quiz_id
        await db.flush()
        return job


document_service = DocumentService()
