from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import (
    AttemptStatus,
    DocumentJob,
    DocumentJobStatus,
    PastPaper,
    Quiz,
    QuizAttempt,
    QuizStatus,
    TutorClass,
    User,
    UserRole,
)


class AdminService:
    async def overview(self, db: AsyncSession) -> dict:
        total_users = await db.scalar(select(func.count()).select_from(User)) or 0
        active_users = await db.scalar(select(func.count()).select_from(User).where(User.is_active.is_(True))) or 0

        role_rows = await db.execute(select(User.role, func.count()).group_by(User.role))
        users_by_role = {row[0].value: row[1] for row in role_rows.all()}

        total_quizzes = await db.scalar(select(func.count()).select_from(Quiz)) or 0
        quiz_status_rows = await db.execute(select(Quiz.status, func.count()).group_by(Quiz.status))
        quizzes_by_status = {row[0].value: row[1] for row in quiz_status_rows.all()}

        total_attempts = await db.scalar(select(func.count()).select_from(QuizAttempt)) or 0
        submitted_attempts = await db.scalar(
            select(func.count()).select_from(QuizAttempt).where(QuizAttempt.status == AttemptStatus.SUBMITTED)
        ) or 0

        total_document_jobs = await db.scalar(select(func.count()).select_from(DocumentJob)) or 0
        job_status_rows = await db.execute(select(DocumentJob.status, func.count()).group_by(DocumentJob.status))
        document_jobs_by_status = {row[0].value: row[1] for row in job_status_rows.all()}

        total_classes = await db.scalar(select(func.count()).select_from(TutorClass)) or 0
        total_past_papers = await db.scalar(select(func.count()).select_from(PastPaper)) or 0

        recent_activity = await self._recent_activity(db)

        return {
            "stats": {
                "total_users": total_users,
                "users_by_role": users_by_role,
                "total_quizzes": total_quizzes,
                "quizzes_by_status": quizzes_by_status,
                "total_attempts": total_attempts,
                "submitted_attempts": submitted_attempts,
                "total_document_jobs": total_document_jobs,
                "document_jobs_by_status": document_jobs_by_status,
                "total_classes": total_classes,
                "total_past_papers": total_past_papers,
                "active_users": active_users,
            },
            "recent_activity": recent_activity,
        }

    async def _recent_activity(self, db: AsyncSession, limit: int = 20) -> list[dict]:
        items: list[dict] = []

        user_rows = await db.execute(select(User).order_by(User.created_at.desc()).limit(5))
        for user in user_rows.scalars().all():
            items.append(
                {
                    "id": str(user.id),
                    "type": "user_registered",
                    "title": user.display_name,
                    "subtitle": user.email,
                    "status": user.role.value,
                    "created_at": user.created_at,
                }
            )

        attempt_rows = await db.execute(
            select(QuizAttempt, Quiz, User)
            .join(Quiz, Quiz.id == QuizAttempt.quiz_id)
            .join(User, User.id == QuizAttempt.user_id)
            .order_by(QuizAttempt.started_at.desc())
            .limit(5)
        )
        for attempt, quiz, user in attempt_rows.all():
            items.append(
                {
                    "id": str(attempt.id),
                    "type": "quiz_attempt",
                    "title": quiz.title,
                    "subtitle": user.display_name,
                    "status": attempt.status.value,
                    "created_at": attempt.submitted_at or attempt.started_at,
                }
            )

        job_rows = await db.execute(
            select(DocumentJob, User)
            .join(User, User.id == DocumentJob.user_id)
            .order_by(DocumentJob.created_at.desc())
            .limit(5)
        )
        for job, user in job_rows.all():
            items.append(
                {
                    "id": str(job.id),
                    "type": "document_upload",
                    "title": job.source_filename,
                    "subtitle": user.display_name,
                    "status": job.status.value,
                    "created_at": job.created_at,
                }
            )

        quiz_rows = await db.execute(select(Quiz).order_by(Quiz.created_at.desc()).limit(5))
        for quiz in quiz_rows.scalars().all():
            items.append(
                {
                    "id": str(quiz.id),
                    "type": "quiz_created",
                    "title": quiz.title,
                    "subtitle": quiz.status.value,
                    "status": quiz.visibility.value,
                    "created_at": quiz.created_at,
                }
            )

        items.sort(key=lambda x: x["created_at"], reverse=True)
        return items[:limit]

    async def list_users(self, db: AsyncSession, skip: int = 0, limit: int = 50) -> dict:
        total = await db.scalar(select(func.count()).select_from(User)) or 0
        result = await db.execute(select(User).order_by(User.created_at.desc()).offset(skip).limit(limit))
        return {"items": list(result.scalars().all()), "total": total}

    async def update_user(self, db: AsyncSession, user_id: UUID, role: UserRole | None, is_active: bool | None) -> User:
        result = await db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        if user is None:
            raise ValueError("User not found")
        if role is not None:
            user.role = role
        if is_active is not None:
            user.is_active = is_active
        await db.flush()
        return user

    async def list_document_jobs(self, db: AsyncSession, limit: int = 50) -> list[dict]:
        result = await db.execute(
            select(DocumentJob, User)
            .join(User, User.id == DocumentJob.user_id)
            .order_by(DocumentJob.created_at.desc())
            .limit(limit)
        )
        return [
            {
                "id": job.id,
                "user_id": job.user_id,
                "user_email": user.email,
                "user_name": user.display_name,
                "status": job.status.value,
                "source_filename": job.source_filename,
                "progress_percent": job.progress_percent,
                "error_log": job.error_log,
                "result_quiz_id": job.result_quiz_id,
                "created_at": job.created_at,
                "updated_at": job.updated_at,
            }
            for job, user in result.all()
        ]

    async def list_quizzes(self, db: AsyncSession, limit: int = 50) -> list[dict]:
        result = await db.execute(
            select(Quiz, User)
            .join(User, User.id == Quiz.creator_id)
            .order_by(Quiz.created_at.desc())
            .limit(limit)
        )
        return [
            {
                "id": quiz.id,
                "title": quiz.title,
                "status": quiz.status.value,
                "visibility": quiz.visibility.value,
                "total_marks": quiz.total_marks,
                "creator_id": quiz.creator_id,
                "creator_name": user.display_name,
                "creator_email": user.email,
                "created_at": quiz.created_at,
            }
            for quiz, user in result.all()
        ]

    async def list_attempts(self, db: AsyncSession, limit: int = 50) -> list[dict]:
        result = await db.execute(
            select(QuizAttempt, Quiz, User)
            .join(Quiz, Quiz.id == QuizAttempt.quiz_id)
            .join(User, User.id == QuizAttempt.user_id)
            .order_by(QuizAttempt.started_at.desc())
            .limit(limit)
        )
        return [
            {
                "id": attempt.id,
                "quiz_id": attempt.quiz_id,
                "quiz_title": quiz.title,
                "user_id": attempt.user_id,
                "user_name": user.display_name,
                "user_email": user.email,
                "score": attempt.score,
                "total_marks": attempt.total_marks,
                "status": attempt.status.value,
                "submitted_at": attempt.submitted_at,
                "started_at": attempt.started_at,
            }
            for attempt, quiz, user in result.all()
        ]


admin_service = AdminService()
