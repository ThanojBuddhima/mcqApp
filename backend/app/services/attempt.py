from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models import AttemptAnswer, AttemptStatus, Question, QuestionOption, Quiz, QuizAttempt
from app.schemas.attempt import AnswerSubmit
from app.services.engagement import leaderboard_service


class AttemptService:
    async def start_attempt(self, db: AsyncSession, quiz_id: UUID, user_id: UUID) -> QuizAttempt:
        quiz = await db.get(Quiz, quiz_id)
        if quiz is None:
            raise ValueError("Quiz not found")

        attempt = QuizAttempt(
            quiz_id=quiz_id,
            user_id=user_id,
            total_marks=quiz.total_marks,
            status=AttemptStatus.IN_PROGRESS,
        )
        db.add(attempt)
        await db.flush()
        reloaded = await self.get_attempt(db, attempt.id)
        assert reloaded is not None
        return reloaded

    async def get_attempt(self, db: AsyncSession, attempt_id: UUID) -> QuizAttempt | None:
        result = await db.execute(
            select(QuizAttempt)
            .options(selectinload(QuizAttempt.answers))
            .where(QuizAttempt.id == attempt_id)
        )
        return result.scalar_one_or_none()

    async def list_attempts_for_user_quiz(
        self, db: AsyncSession, quiz_id: UUID, user_id: UUID
    ) -> list[QuizAttempt]:
        result = await db.execute(
            select(QuizAttempt)
            .options(selectinload(QuizAttempt.answers))
            .where(
                QuizAttempt.quiz_id == quiz_id,
                QuizAttempt.user_id == user_id,
                QuizAttempt.status == AttemptStatus.SUBMITTED,
            )
            .order_by(QuizAttempt.submitted_at.desc())
        )
        return list(result.scalars().all())

    async def submit_answers(
        self, db: AsyncSession, attempt: QuizAttempt, answers: list[AnswerSubmit]
    ) -> QuizAttempt:
        if attempt.status != AttemptStatus.IN_PROGRESS:
            raise ValueError("Attempt already submitted")

        for ans in answers:
            question = await db.get(Question, ans.question_id)
            if question is None or question.quiz_id != attempt.quiz_id:
                continue

            is_correct, marks = self._score_answer(question, ans)
            existing = await db.execute(
                select(AttemptAnswer).where(
                    AttemptAnswer.attempt_id == attempt.id,
                    AttemptAnswer.question_id == ans.question_id,
                )
            )
            record = existing.scalar_one_or_none()
            if record:
                record.selected_answer = ans.selected_answer
                record.text_answer = ans.text_answer
                record.is_correct = is_correct
                record.marks_awarded = marks
            else:
                db.add(
                    AttemptAnswer(
                        attempt_id=attempt.id,
                        question_id=ans.question_id,
                        selected_answer=ans.selected_answer,
                        text_answer=ans.text_answer,
                        is_correct=is_correct,
                        marks_awarded=marks,
                    )
                )
        await db.flush()
        return await self.get_attempt(db, attempt.id)

    async def submit_attempt(self, db: AsyncSession, attempt: QuizAttempt) -> QuizAttempt:
        if attempt.status != AttemptStatus.IN_PROGRESS:
            raise ValueError("Attempt already submitted")

        result = await db.execute(
            select(AttemptAnswer).where(AttemptAnswer.attempt_id == attempt.id)
        )
        answers = list(result.scalars().all())
        attempt.score = sum(a.marks_awarded for a in answers)
        attempt.status = AttemptStatus.SUBMITTED
        attempt.submitted_at = datetime.now(timezone.utc)

        if attempt.started_at:
            delta = attempt.submitted_at - attempt.started_at
            attempt.duration_seconds = int(delta.total_seconds())

        await leaderboard_service.update_score(db, attempt)
        await db.flush()
        reloaded = await self.get_attempt(db, attempt.id)
        assert reloaded is not None
        return reloaded

    async def get_review(self, db: AsyncSession, attempt: QuizAttempt) -> dict:
        result = await db.execute(
            select(Question)
            .options(selectinload(Question.options))
            .where(Question.quiz_id == attempt.quiz_id)
            .order_by(Question.order_index)
        )
        questions = list(result.scalars().all())
        answers_map = {a.question_id: a for a in attempt.answers}

        review_questions = []
        for q in questions:
            ans = answers_map.get(q.id)
            review_questions.append(
                {
                    "question_id": str(q.id),
                    "question_text": q.question_text,
                    "question_image_url": q.question_image_url,
                    "type": q.type.value,
                    "marks": q.marks,
                    "correct_answer": q.correct_answer,
                    "explanation": q.explanation,
                    "options": [
                        {"label": o.label, "text": o.option_text, "is_correct": o.is_correct}
                        for o in q.options
                    ],
                    "user_answer": ans.selected_answer if ans else None,
                    "is_correct": ans.is_correct if ans else None,
                    "marks_awarded": ans.marks_awarded if ans else 0,
                }
            )

        return {"attempt": attempt, "questions": review_questions}

    def _score_answer(self, question: Question, ans: AnswerSubmit) -> tuple[bool | None, int]:
        if question.type.value == "mcq":
            is_correct = ans.selected_answer == question.correct_answer
            return is_correct, question.marks if is_correct else 0
        if question.type.value == "structured":
            return None, 0
        return None, 0


attempt_service = AttemptService()
