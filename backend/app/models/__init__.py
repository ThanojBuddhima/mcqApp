import enum
import uuid
from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    Enum,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class UserRole(str, enum.Enum):
    STUDENT = "student"
    TUTOR = "tutor"
    ADMIN = "admin"


class QuizStatus(str, enum.Enum):
    DRAFT = "draft"
    PUBLISHED = "published"
    ARCHIVED = "archived"


class QuizVisibility(str, enum.Enum):
    PRIVATE = "private"
    PUBLIC = "public"
    CLASS_ONLY = "class_only"


class QuestionType(str, enum.Enum):
    MCQ = "mcq"
    STRUCTURED = "structured"
    TRUE_FALSE = "true_false"


class AttemptStatus(str, enum.Enum):
    IN_PROGRESS = "in_progress"
    SUBMITTED = "submitted"
    ABANDONED = "abandoned"


class DocumentJobStatus(str, enum.Enum):
    PENDING = "pending"
    PREPROCESSING = "preprocessing"
    LAYOUT = "layout"
    OCR = "ocr"
    SEGMENTATION = "segmentation"
    AI_PARSE = "ai_parse"
    COMPLETED = "completed"
    FAILED = "failed"


class Medium(str, enum.Enum):
    SINHALA = "sinhala"
    ENGLISH = "english"
    TAMIL = "tamil"


class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    password_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    google_id: Mapped[str | None] = mapped_column(String(255), unique=True, nullable=True)
    display_name: Mapped[str] = mapped_column(String(255), nullable=False)
    grade: Mapped[str | None] = mapped_column(String(10), nullable=True)
    role: Mapped[UserRole] = mapped_column(Enum(UserRole), default=UserRole.STUDENT, nullable=False)
    profile: Mapped[dict] = mapped_column(JSONB, default=dict)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    quizzes: Mapped[list["Quiz"]] = relationship(back_populates="creator")
    attempts: Mapped[list["QuizAttempt"]] = relationship(back_populates="user")


class Subject(Base):
    __tablename__ = "subjects"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name_en: Mapped[str] = mapped_column(String(255), nullable=False)
    name_si: Mapped[str | None] = mapped_column(String(255), nullable=True)
    grade_levels: Mapped[list] = mapped_column(JSONB, default=list)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    past_papers: Mapped[list["PastPaper"]] = relationship(back_populates="subject")


class Quiz(Base):
    __tablename__ = "quizzes"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    creator_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    title: Mapped[str] = mapped_column(String(500), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[QuizStatus] = mapped_column(Enum(QuizStatus), default=QuizStatus.DRAFT)
    visibility: Mapped[QuizVisibility] = mapped_column(Enum(QuizVisibility), default=QuizVisibility.PRIVATE)
    content: Mapped[dict] = mapped_column(JSONB, default=dict)
    time_limit_minutes: Mapped[int | None] = mapped_column(Integer, nullable=True)
    total_marks: Mapped[int] = mapped_column(Integer, default=0)
    share_code: Mapped[str | None] = mapped_column(String(12), unique=True, nullable=True, index=True)
    price_lkr: Mapped[float | None] = mapped_column(Numeric(10, 2), nullable=True)
    metadata_extra: Mapped[dict] = mapped_column(JSONB, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    creator: Mapped["User"] = relationship(back_populates="quizzes")
    questions: Mapped[list["Question"]] = relationship(back_populates="quiz", cascade="all, delete-orphan")
    attempts: Mapped[list["QuizAttempt"]] = relationship(back_populates="quiz")
    past_paper: Mapped["PastPaper | None"] = relationship(back_populates="quiz", uselist=False)


class Question(Base):
    __tablename__ = "questions"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    quiz_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("quizzes.id"), nullable=False)
    order_index: Mapped[int] = mapped_column(Integer, default=0)
    type: Mapped[QuestionType] = mapped_column(Enum(QuestionType), default=QuestionType.MCQ)
    question_text: Mapped[str] = mapped_column(Text, nullable=False)
    question_image_url: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    layout_refs: Mapped[dict] = mapped_column(JSONB, default=dict)
    marks: Mapped[int] = mapped_column(Integer, default=1)
    explanation: Mapped[str | None] = mapped_column(Text, nullable=True)
    difficulty: Mapped[str | None] = mapped_column(String(50), nullable=True)
    correct_answer: Mapped[str | None] = mapped_column(String(255), nullable=True)

    quiz: Mapped["Quiz"] = relationship(back_populates="questions")
    options: Mapped[list["QuestionOption"]] = relationship(
        back_populates="question", cascade="all, delete-orphan"
    )


class QuestionOption(Base):
    __tablename__ = "question_options"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    question_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("questions.id"), nullable=False)
    label: Mapped[str] = mapped_column(String(10), nullable=False)
    option_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    option_image_url: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    is_correct: Mapped[bool] = mapped_column(Boolean, default=False)

    question: Mapped["Question"] = relationship(back_populates="options")


class QuizAttempt(Base):
    __tablename__ = "quiz_attempts"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    quiz_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("quizzes.id"), nullable=False)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    score: Mapped[int | None] = mapped_column(Integer, nullable=True)
    total_marks: Mapped[int | None] = mapped_column(Integer, nullable=True)
    duration_seconds: Mapped[int | None] = mapped_column(Integer, nullable=True)
    status: Mapped[AttemptStatus] = mapped_column(Enum(AttemptStatus), default=AttemptStatus.IN_PROGRESS)
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    submitted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    quiz: Mapped["Quiz"] = relationship(back_populates="attempts")
    user: Mapped["User"] = relationship(back_populates="attempts")
    answers: Mapped[list["AttemptAnswer"]] = relationship(back_populates="attempt", cascade="all, delete-orphan")


class AttemptAnswer(Base):
    __tablename__ = "attempt_answers"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    attempt_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("quiz_attempts.id"), nullable=False)
    question_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("questions.id"), nullable=False)
    selected_answer: Mapped[str | None] = mapped_column(String(255), nullable=True)
    text_answer: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_correct: Mapped[bool | None] = mapped_column(Boolean, nullable=True)
    marks_awarded: Mapped[int] = mapped_column(Integer, default=0)

    attempt: Mapped["QuizAttempt"] = relationship(back_populates="answers")


class DocumentJob(Base):
    __tablename__ = "document_jobs"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    status: Mapped[DocumentJobStatus] = mapped_column(Enum(DocumentJobStatus), default=DocumentJobStatus.PENDING)
    source_file_url: Mapped[str] = mapped_column(String(1024), nullable=False)
    source_filename: Mapped[str] = mapped_column(String(500), nullable=False)
    page_count: Mapped[int] = mapped_column(Integer, default=0)
    progress_percent: Mapped[int] = mapped_column(Integer, default=0)
    error_log: Mapped[str | None] = mapped_column(Text, nullable=True)
    result_quiz_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("quizzes.id"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    pages: Mapped[list["DocumentPage"]] = relationship(back_populates="job", cascade="all, delete-orphan")


class DocumentPage(Base):
    __tablename__ = "document_pages"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    job_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("document_jobs.id"), nullable=False)
    page_index: Mapped[int] = mapped_column(Integer, nullable=False)
    image_url: Mapped[str] = mapped_column(String(1024), nullable=False)
    layout_json: Mapped[dict] = mapped_column(JSONB, default=dict)

    job: Mapped["DocumentJob"] = relationship(back_populates="pages")
    blocks: Mapped[list["DocumentBlock"]] = relationship(back_populates="page", cascade="all, delete-orphan")


class DocumentBlock(Base):
    __tablename__ = "document_blocks"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    page_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("document_pages.id"), nullable=False)
    block_type: Mapped[str] = mapped_column(String(50), nullable=False)
    bbox: Mapped[list] = mapped_column(JSONB, default=list)
    ocr_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    ocr_lang: Mapped[str | None] = mapped_column(String(10), nullable=True)
    confidence: Mapped[float | None] = mapped_column(Numeric(5, 4), nullable=True)
    needs_review: Mapped[bool] = mapped_column(Boolean, default=False)
    figure_url: Mapped[str | None] = mapped_column(String(1024), nullable=True)

    page: Mapped["DocumentPage"] = relationship(back_populates="blocks")


class PastPaper(Base):
    __tablename__ = "past_papers"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    quiz_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("quizzes.id"), unique=True, nullable=False)
    subject_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("subjects.id"), nullable=False)
    grade: Mapped[str] = mapped_column(String(20), nullable=False)
    medium: Mapped[Medium] = mapped_column(Enum(Medium), nullable=False)
    year: Mapped[int] = mapped_column(Integer, nullable=False)
    exam_type: Mapped[str] = mapped_column(String(100), nullable=False)
    answer_scheme_url: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    original_pdf_url: Mapped[str | None] = mapped_column(String(1024), nullable=True)

    quiz: Mapped["Quiz"] = relationship(back_populates="past_paper")
    subject: Mapped["Subject"] = relationship(back_populates="past_papers")


class Favorite(Base):
    __tablename__ = "favorites"
    __table_args__ = (UniqueConstraint("user_id", "quiz_id", name="uq_user_quiz_favorite"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    quiz_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("quizzes.id"), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class TutorClass(Base):
    __tablename__ = "classes"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    tutor_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    enrollment_code: Mapped[str] = mapped_column(String(12), unique=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class ClassEnrollment(Base):
    __tablename__ = "class_enrollments"
    __table_args__ = (UniqueConstraint("class_id", "student_id", name="uq_class_student"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    class_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("classes.id"), nullable=False)
    student_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    enrolled_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class MarketplaceItem(Base):
    __tablename__ = "marketplace_items"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    seller_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    quiz_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("quizzes.id"), unique=True, nullable=False)
    price_lkr: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)
    is_premium: Mapped[bool] = mapped_column(Boolean, default=True)
    rating_avg: Mapped[float] = mapped_column(Numeric(3, 2), default=0)
    rating_count: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
