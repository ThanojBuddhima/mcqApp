from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models import Question, QuestionOption, QuestionType, Quiz, QuizStatus, QuizVisibility
from app.schemas.quiz import QuestionCreate, QuizCreate, QuizUpdate
from app.services.storage import generate_share_code


class QuizService:
    async def create(self, db: AsyncSession, creator_id: UUID, data: QuizCreate) -> Quiz:
        quiz = Quiz(
            creator_id=creator_id,
            title=data.title,
            description=data.description,
            time_limit_minutes=data.time_limit_minutes,
            visibility=QuizVisibility(data.visibility.value),
            metadata_extra=data.metadata_extra,
            content={"questions": []},
        )
        db.add(quiz)
        await db.flush()

        total_marks = 0
        for q_data in data.questions:
            question = self._build_question(quiz.id, q_data)
            total_marks += question.marks
            db.add(question)

        quiz.total_marks = total_marks
        await db.flush()
        quiz = await self.get_by_id(db, quiz.id)
        assert quiz is not None
        quiz.content = self._build_content_json(quiz)
        await db.flush()
        return await self.get_by_id(db, quiz.id)

    async def get_by_id(self, db: AsyncSession, quiz_id: UUID) -> Quiz | None:
        result = await db.execute(
            select(Quiz)
            .options(selectinload(Quiz.questions).selectinload(Question.options))
            .where(Quiz.id == quiz_id)
        )
        return result.scalar_one_or_none()

    async def list_quizzes(
        self,
        db: AsyncSession,
        *,
        creator_id: UUID | None = None,
        status: QuizStatus | None = None,
        skip: int = 0,
        limit: int = 20,
    ) -> tuple[list[Quiz], int]:
        query = select(Quiz).options(selectinload(Quiz.questions).selectinload(Question.options))
        count_query = select(func.count()).select_from(Quiz)

        if creator_id:
            query = query.where(Quiz.creator_id == creator_id)
            count_query = count_query.where(Quiz.creator_id == creator_id)
        if status:
            query = query.where(Quiz.status == status)
            count_query = count_query.where(Quiz.status == status)

        total = (await db.execute(count_query)).scalar_one()
        result = await db.execute(query.order_by(Quiz.created_at.desc()).offset(skip).limit(limit))
        return list(result.scalars().all()), total

    async def update(self, db: AsyncSession, quiz: Quiz, data: QuizUpdate) -> Quiz:
        if data.title is not None:
            quiz.title = data.title
        if data.description is not None:
            quiz.description = data.description
        if data.time_limit_minutes is not None:
            quiz.time_limit_minutes = data.time_limit_minutes
        if data.visibility is not None:
            quiz.visibility = QuizVisibility(data.visibility.value)
        if data.status is not None:
            quiz.status = QuizStatus(data.status.value)
        if data.metadata_extra is not None:
            quiz.metadata_extra = data.metadata_extra

        if data.questions is not None:
            for q in list(quiz.questions):
                await db.delete(q)
            await db.flush()

            total_marks = 0
            for q_data in data.questions:
                question = self._build_question(quiz.id, q_data)
                total_marks += question.marks
                db.add(question)
            quiz.total_marks = total_marks

            quiz.total_marks = total_marks

        reloaded = await self.get_by_id(db, quiz.id)
        assert reloaded is not None
        reloaded.content = self._build_content_json(reloaded)
        await db.flush()
        return await self.get_by_id(db, quiz.id)

    async def publish(self, db: AsyncSession, quiz: Quiz) -> Quiz:
        if not quiz.questions:
            raise ValueError("Quiz must have at least one question")
        quiz.status = QuizStatus.PUBLISHED
        await db.flush()
        return quiz

    async def generate_share_code(self, db: AsyncSession, quiz: Quiz) -> str:
        code = generate_share_code()
        quiz.share_code = code
        await db.flush()
        return code

    async def get_by_share_code(self, db: AsyncSession, code: str) -> Quiz | None:
        result = await db.execute(
            select(Quiz)
            .options(selectinload(Quiz.questions).selectinload(Question.options))
            .where(Quiz.share_code == code.upper())
        )
        return result.scalar_one_or_none()

    def _build_question(self, quiz_id: UUID, data: QuestionCreate) -> Question:
        question = Question(
            quiz_id=quiz_id,
            order_index=data.order_index,
            type=QuestionType(data.type.value),
            question_text=data.question_text,
            question_image_url=data.question_image_url,
            layout_refs=data.layout_refs,
            marks=data.marks,
            explanation=data.explanation,
            difficulty=data.difficulty,
            correct_answer=data.correct_answer,
        )
        for opt in data.options:
            question.options.append(
                QuestionOption(
                    label=opt.label,
                    option_text=opt.option_text,
                    option_image_url=opt.option_image_url,
                    is_correct=opt.is_correct,
                )
            )
        if not question.correct_answer:
            for opt in question.options:
                if opt.is_correct:
                    question.correct_answer = opt.label
                    break
        return question

    def _build_content_json(self, quiz: Quiz) -> dict:
        questions = sorted(quiz.questions, key=lambda q: q.order_index)
        return {
            "quizTitle": quiz.title,
            "metadata": quiz.metadata_extra,
            "settings": {
                "timeLimitMinutes": quiz.time_limit_minutes,
                "totalMarks": quiz.total_marks,
            },
            "questions": [
                {
                    "id": str(q.id),
                    "order": q.order_index,
                    "type": q.type.value,
                    "questionText": q.question_text,
                    "questionImage": q.question_image_url,
                    "layoutRefs": q.layout_refs,
                    "options": [
                        {
                            "id": o.label,
                            "text": o.option_text,
                            "image": o.option_image_url,
                            "isCorrect": o.is_correct,
                        }
                        for o in sorted(q.options, key=lambda x: x.label)
                    ],
                    "correctAnswer": q.correct_answer,
                    "marks": q.marks,
                    "explanation": q.explanation,
                    "difficulty": q.difficulty,
                }
                for q in questions
            ],
        }


quiz_service = QuizService()
