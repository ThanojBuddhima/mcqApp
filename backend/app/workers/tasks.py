import sys
from pathlib import Path
from uuid import UUID

# Add pipeline to path for worker
ROOT = Path(__file__).resolve().parents[3]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.config import settings
from app.models import (
    DocumentJob,
    DocumentJobStatus,
    Question,
    QuestionOption,
    QuestionType,
    Quiz,
    QuizStatus,
)
from app.services.storage import storage_service
from app.workers.celery_app import celery_app
from pipeline.processor import DocumentProcessor


sync_engine = create_engine(settings.database_url_sync)
SessionLocal = sessionmaker(bind=sync_engine)


def _download_file(url: str) -> bytes:
    key = url.split(f"/{settings.s3_bucket}/")[-1]
    return storage_service.download_bytes(key)


@celery_app.task(name="process_document", bind=True, max_retries=2)
def process_document_task(self, job_id: str):
    db = SessionLocal()
    try:
        job = db.get(DocumentJob, UUID(job_id))
        if job is None:
            return {"error": "Job not found"}

        def update_progress(stage: str, pct: int):
            status_map = {
                "preprocessing": DocumentJobStatus.PREPROCESSING,
                "layout": DocumentJobStatus.LAYOUT,
                "ocr": DocumentJobStatus.OCR,
                "segmentation": DocumentJobStatus.SEGMENTATION,
                "ai_parse": DocumentJobStatus.AI_PARSE,
                "done": DocumentJobStatus.COMPLETED,
            }
            job.status = status_map.get(stage, job.status)
            job.progress_percent = pct
            db.commit()

        file_bytes = _download_file(job.source_file_url)

        processor = DocumentProcessor(
            upload_fn=lambda key, data, ct: storage_service.upload_bytes(key, data, ct),
            gemini_api_key=settings.gemini_api_key or None,
        )

        result = processor.process(file_bytes, job.source_filename, job_id, on_progress=update_progress)

        quiz_json = result["quiz_json"]
        quiz = Quiz(
            creator_id=job.user_id,
            title=quiz_json.get("quizTitle", job.source_filename),
            status=QuizStatus.DRAFT,
            content=quiz_json,
            time_limit_minutes=quiz_json.get("settings", {}).get("timeLimitMinutes"),
            total_marks=quiz_json.get("settings", {}).get("totalMarks", 0),
            metadata_extra=quiz_json.get("metadata", {}),
        )
        db.add(quiz)
        db.flush()

        for q_data in quiz_json.get("questions", []):
            q_type = QuestionType.MCQ if q_data.get("type") == "mcq" else QuestionType.STRUCTURED
            question = Question(
                quiz_id=quiz.id,
                order_index=q_data.get("order", 0),
                type=q_type,
                question_text=q_data.get("questionText", ""),
                question_image_url=q_data.get("questionImage"),
                layout_refs=q_data.get("layoutRefs", {}),
                marks=q_data.get("marks", 1),
                explanation=q_data.get("explanation"),
                difficulty=q_data.get("difficulty"),
                correct_answer=q_data.get("correctAnswer"),
            )
            db.add(question)
            db.flush()
            for opt in q_data.get("options", []):
                db.add(
                    QuestionOption(
                        question_id=question.id,
                        label=str(opt.get("id", "")),
                        option_text=opt.get("text"),
                        option_image_url=opt.get("image"),
                        is_correct=opt.get("isCorrect", False)
                        or str(opt.get("id")) == str(q_data.get("correctAnswer")),
                    )
                )

        job.result_quiz_id = quiz.id
        job.page_count = result["page_count"]
        job.status = DocumentJobStatus.COMPLETED
        job.progress_percent = 100
        db.commit()

        return {"job_id": job_id, "quiz_id": str(quiz.id), "questions": len(quiz_json.get("questions", []))}

    except Exception as exc:
        db.rollback()
        job = db.get(DocumentJob, UUID(job_id))
        if job:
            job.status = DocumentJobStatus.FAILED
            job.error_log = str(exc)
            db.commit()
        raise self.retry(exc=exc, countdown=30) from exc
    finally:
        db.close()
