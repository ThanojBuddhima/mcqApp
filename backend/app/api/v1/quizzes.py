from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user, require_tutor
from app.models import QuizStatus, User
from app.schemas.quiz import QuizCreate, QuizListResponse, QuizResponse, QuizUpdate, ShareCodeResponse
from app.schemas.attempt import AttemptResponse
from app.services.attempt import attempt_service
from app.services.quiz import quiz_service

router = APIRouter()


@router.post("", response_model=QuizResponse, status_code=status.HTTP_201_CREATED)
async def create_quiz(
    data: QuizCreate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    quiz = await quiz_service.create(db, user.id, data)
    return quiz


@router.get("", response_model=QuizListResponse)
async def list_quizzes(
    status_filter: QuizStatus | None = Query(None, alias="status"),
    mine: bool = Query(False),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    creator_id = user.id if mine else None
    effective_status = status_filter or (QuizStatus.PUBLISHED if not mine else None)
    items, total = await quiz_service.list_quizzes(
        db, creator_id=creator_id, status=effective_status, skip=skip, limit=limit
    )
    return QuizListResponse(items=items, total=total)


@router.get("/code/{code}", response_model=QuizResponse)
async def get_quiz_by_code(code: str, db: AsyncSession = Depends(get_db)):
    quiz = await quiz_service.get_by_share_code(db, code)
    if quiz is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Quiz not found")
    return quiz


@router.get("/{quiz_id}", response_model=QuizResponse)
async def get_quiz(quiz_id: UUID, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    quiz = await quiz_service.get_by_id(db, quiz_id)
    if quiz is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Quiz not found")
    return quiz


@router.put("/{quiz_id}", response_model=QuizResponse)
async def update_quiz(
    quiz_id: UUID,
    data: QuizUpdate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(require_tutor),
):
    quiz = await quiz_service.get_by_id(db, quiz_id)
    if quiz is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Quiz not found")
    if quiz.creator_id != user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your quiz")
    return await quiz_service.update(db, quiz, data)


@router.post("/{quiz_id}/publish", response_model=QuizResponse)
async def publish_quiz(
    quiz_id: UUID,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    quiz = await quiz_service.get_by_id(db, quiz_id)
    if quiz is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Quiz not found")
    if quiz.creator_id != user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your quiz")
    try:
        return await quiz_service.publish(db, quiz)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.get("/{quiz_id}/attempts/me", response_model=list[AttemptResponse])
async def list_my_quiz_attempts(
    quiz_id: UUID,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return await attempt_service.list_attempts_for_user_quiz(db, quiz_id, user.id)


@router.post("/{quiz_id}/attempts", response_model=AttemptResponse, status_code=status.HTTP_201_CREATED)
async def start_attempt(
    quiz_id: UUID,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    try:
        attempt = await attempt_service.start_attempt(db, quiz_id, user.id)
        return attempt
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc


@router.post("/{quiz_id}/share", response_model=ShareCodeResponse)
async def share_quiz(
    quiz_id: UUID,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(require_tutor),
):
    quiz = await quiz_service.get_by_id(db, quiz_id)
    if quiz is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Quiz not found")
    if quiz.creator_id != user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your quiz")
    code = await quiz_service.generate_share_code(db, quiz)
    return ShareCodeResponse(share_code=code, share_url=f"/quizzes/code/{code}")
