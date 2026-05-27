from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models import PastPaper, Quiz, Subject
from app.schemas.past_paper import PastPaperCreate


class PastPaperService:
    async def create(self, db: AsyncSession, data: PastPaperCreate) -> PastPaper:
        past_paper = PastPaper(
            quiz_id=data.quiz_id,
            subject_id=data.subject_id,
            grade=data.grade,
            medium=data.medium,
            year=data.year,
            exam_type=data.exam_type,
            answer_scheme_url=data.answer_scheme_url,
            original_pdf_url=data.original_pdf_url,
        )
        db.add(past_paper)
        await db.flush()
        return past_paper

    async def list_papers(
        self,
        db: AsyncSession,
        *,
        grade: str | None = None,
        subject_id: UUID | None = None,
        medium: str | None = None,
        year: int | None = None,
        exam_type: str | None = None,
        skip: int = 0,
        limit: int = 20,
    ) -> list[dict]:
        query = (
            select(PastPaper, Quiz, Subject)
            .join(Quiz, PastPaper.quiz_id == Quiz.id)
            .join(Subject, PastPaper.subject_id == Subject.id)
        )
        if grade:
            query = query.where(PastPaper.grade == grade)
        if subject_id:
            query = query.where(PastPaper.subject_id == subject_id)
        if medium:
            query = query.where(PastPaper.medium == medium)
        if year:
            query = query.where(PastPaper.year == year)
        if exam_type:
            query = query.where(PastPaper.exam_type == exam_type)

        result = await db.execute(query.order_by(PastPaper.year.desc()).offset(skip).limit(limit))
        rows = []
        for pp, quiz, subject in result.all():
            rows.append(
                {
                    "id": pp.id,
                    "quiz_id": pp.quiz_id,
                    "subject_id": pp.subject_id,
                    "grade": pp.grade,
                    "medium": pp.medium,
                    "year": pp.year,
                    "exam_type": pp.exam_type,
                    "answer_scheme_url": pp.answer_scheme_url,
                    "original_pdf_url": pp.original_pdf_url,
                    "quiz_title": quiz.title,
                    "subject_name": subject.name_en,
                }
            )
        return rows

    async def get_by_id(self, db: AsyncSession, paper_id: UUID) -> PastPaper | None:
        return await db.get(PastPaper, paper_id)

    async def list_subjects(self, db: AsyncSession) -> list[Subject]:
        result = await db.execute(select(Subject).order_by(Subject.name_en))
        return list(result.scalars().all())


past_paper_service = PastPaperService()
