from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models import ClassEnrollment, Question, Quiz, QuizAttempt, AttemptStatus, TutorClass, User
from app.services.storage import generate_share_code


class ClassService:
    async def create(self, db: AsyncSession, tutor_id: UUID, name: str, description: str | None) -> TutorClass:
        cls = TutorClass(
            tutor_id=tutor_id,
            name=name,
            description=description,
            enrollment_code=generate_share_code(6),
        )
        db.add(cls)
        await db.flush()
        return cls

    async def list_for_tutor(self, db: AsyncSession, tutor_id: UUID) -> list[TutorClass]:
        result = await db.execute(
            select(TutorClass).where(TutorClass.tutor_id == tutor_id).order_by(TutorClass.created_at.desc())
        )
        return list(result.scalars().all())

    async def get_by_id(self, db: AsyncSession, class_id: UUID) -> TutorClass | None:
        return await db.get(TutorClass, class_id)

    async def enroll_by_code(self, db: AsyncSession, student_id: UUID, code: str) -> ClassEnrollment:
        result = await db.execute(
            select(TutorClass).where(TutorClass.enrollment_code == code.upper())
        )
        cls = result.scalar_one_or_none()
        if cls is None:
            raise ValueError("Invalid enrollment code")

        existing = await db.execute(
            select(ClassEnrollment).where(
                ClassEnrollment.class_id == cls.id,
                ClassEnrollment.student_id == student_id,
            )
        )
        if existing.scalar_one_or_none():
            raise ValueError("Already enrolled")

        enrollment = ClassEnrollment(class_id=cls.id, student_id=student_id)
        db.add(enrollment)
        await db.flush()
        return enrollment

    async def list_students(self, db: AsyncSession, class_id: UUID) -> list[User]:
        result = await db.execute(
            select(User)
            .join(ClassEnrollment, ClassEnrollment.student_id == User.id)
            .where(ClassEnrollment.class_id == class_id)
        )
        return list(result.scalars().all())

    async def get_analytics(self, db: AsyncSession, class_id: UUID) -> dict:
        students = await self.list_students(db, class_id)
        student_ids = [s.id for s in students]

        if not student_ids:
            return {"student_count": 0, "avg_score": 0, "attempts_count": 0, "students": []}

        result = await db.execute(
            select(QuizAttempt)
            .where(
                QuizAttempt.user_id.in_(student_ids),
                QuizAttempt.status == AttemptStatus.SUBMITTED,
            )
        )
        attempts = list(result.scalars().all())
        scores = [a.score for a in attempts if a.score is not None]
        avg_score = sum(scores) / len(scores) if scores else 0

        student_stats = []
        for student in students:
            student_attempts = [a for a in attempts if a.user_id == student.id]
            student_scores = [a.score for a in student_attempts if a.score is not None]
            student_stats.append(
                {
                    "student_id": str(student.id),
                    "display_name": student.display_name,
                    "attempts": len(student_attempts),
                    "avg_score": sum(student_scores) / len(student_scores) if student_scores else 0,
                }
            )

        return {
            "student_count": len(students),
            "avg_score": round(avg_score, 2),
            "attempts_count": len(attempts),
            "students": student_stats,
        }


class AnalyticsService:
    async def student_dashboard(self, db: AsyncSession, user_id: UUID) -> dict:
        result = await db.execute(
            select(QuizAttempt)
            .where(QuizAttempt.user_id == user_id, QuizAttempt.status == AttemptStatus.SUBMITTED)
            .order_by(QuizAttempt.submitted_at.desc())
        )
        attempts = list(result.scalars().all())
        scores = [a.score for a in attempts if a.score is not None]
        total_marks = [a.total_marks for a in attempts if a.total_marks]

        return {
            "total_attempts": len(attempts),
            "avg_score": round(sum(scores) / len(scores), 2) if scores else 0,
            "avg_percentage": round(
                sum(s / t * 100 for s, t in zip(scores, total_marks) if t) / len(scores), 2
            )
            if scores and total_marks
            else 0,
            "recent_attempts": [
                {
                    "attempt_id": str(a.id),
                    "quiz_id": str(a.quiz_id),
                    "score": a.score,
                    "total_marks": a.total_marks,
                    "submitted_at": a.submitted_at.isoformat() if a.submitted_at else None,
                }
                for a in attempts[:10]
            ],
        }


class_service = ClassService()
analytics_service = AnalyticsService()
