"""Seed database with subjects, demo users, sample quiz and past paper."""

import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "backend"))

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.core.config import settings
from app.core.database import Base
from app.core.security import hash_password
from app.models import (
    Medium,
    PastPaper,
    Question,
    QuestionOption,
    QuestionType,
    Quiz,
    QuizStatus,
    QuizVisibility,
    Subject,
    User,
    UserRole,
)

engine = create_async_engine(settings.database_url)
Session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

SUBJECTS = [
    {"name_en": "Mathematics", "name_si": "ගණිතය", "grade_levels": ["6", "7", "8", "9", "10", "11"]},
    {"name_en": "Science", "name_si": "විද්‍යාව", "grade_levels": ["6", "7", "8", "9", "10", "11"]},
    {"name_en": "Physics", "name_si": "භෞතික විද්‍යාව", "grade_levels": ["10", "11", "12", "13"]},
    {"name_en": "Chemistry", "name_si": "රසායන විද්‍යාව", "grade_levels": ["10", "11", "12", "13"]},
    {"name_en": "Biology", "name_si": "ජීව විද්‍යාව", "grade_levels": ["10", "11", "12", "13"]},
    {"name_en": "Sinhala", "name_si": "සිංහල", "grade_levels": ["6", "7", "8", "9", "10", "11"]},
    {"name_en": "English", "name_si": "ඉංග්‍රීසි", "grade_levels": ["6", "7", "8", "9", "10", "11"]},
    {"name_en": "History", "name_si": "ඉතිහාසය", "grade_levels": ["6", "7", "8", "9", "10", "11"]},
]


async def seed():
    async with Session() as db:
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)

        for subj in SUBJECTS:
            exists = await db.execute(select(Subject).where(Subject.name_en == subj["name_en"]))
            if exists.scalar_one_or_none() is None:
                db.add(Subject(**subj))

        tutor = await _get_or_create_user(
            db, "tutor@demo.lk", "Demo Tutor", UserRole.TUTOR, "demo1234"
        )
        await _get_or_create_user(db, "student@demo.lk", "Demo Student", UserRole.STUDENT, "demo1234")
        await _get_or_create_user(db, "admin@demo.lk", "Demo Admin", UserRole.ADMIN, "Demo1234!")

        physics = (await db.execute(select(Subject).where(Subject.name_en == "Physics"))).scalar_one()

        existing_quiz = await db.execute(
            select(Quiz).where(Quiz.title == "O/L Physics 2023 - Sample MCQ")
        )
        if existing_quiz.scalar_one_or_none() is None:
            quiz = Quiz(
                creator_id=tutor.id,
                title="O/L Physics 2023 - Sample MCQ",
                description="Sample past paper style quiz for testing",
                status=QuizStatus.PUBLISHED,
                visibility=QuizVisibility.PUBLIC,
                time_limit_minutes=30,
                total_marks=2,
                content={},
            )
            db.add(quiz)
            await db.flush()

            q1 = Question(
                quiz_id=quiz.id,
                order_index=0,
                type=QuestionType.MCQ,
                question_text="What is the SI unit of force?",
                marks=1,
                correct_answer="A",
                explanation="Force is measured in Newtons (N).",
            )
            q1.options = [
                QuestionOption(label="A", option_text="Newton", is_correct=True),
                QuestionOption(label="B", option_text="Joule", is_correct=False),
                QuestionOption(label="C", option_text="Watt", is_correct=False),
            ]
            q2 = Question(
                quiz_id=quiz.id,
                order_index=1,
                type=QuestionType.MCQ,
                question_text="විද්‍යුත් ධාරාවේ SI ඒකකය කුමක්ද?",
                marks=1,
                correct_answer="A",
                explanation="Electric current is measured in Amperes.",
            )
            q2.options = [
                QuestionOption(label="A", option_text="Amperes", is_correct=True),
                QuestionOption(label="B", option_text="Volts", is_correct=False),
            ]
            db.add(q1)
            db.add(q2)

            quiz.content = {
                "quizTitle": quiz.title,
                "questions": [
                    {"id": str(q1.id), "questionText": q1.question_text, "type": "mcq"},
                    {"id": str(q2.id), "questionText": q2.question_text, "type": "mcq"},
                ],
            }

            db.add(
                PastPaper(
                    quiz_id=quiz.id,
                    subject_id=physics.id,
                    grade="11",
                    medium=Medium.ENGLISH,
                    year=2023,
                    exam_type="O/L",
                )
            )

        await db.commit()
        print("Seed complete!")
        print("  tutor@demo.lk / demo1234")
        print("  student@demo.lk / demo1234")
        print("  admin@demo.lk / Demo1234!")


async def _get_or_create_user(db, email, name, role, password):
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()
    if user is None:
        user = User(email=email, password_hash=hash_password(password), display_name=name, role=role, grade="O/L")
        db.add(user)
        await db.flush()
    return user


if __name__ == "__main__":
    asyncio.run(seed())
