from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models import User
from app.schemas.attempt import AnswersBatchSubmit, AttemptResponse, AttemptReviewResponse
from app.services.attempt import attempt_service

router = APIRouter()


@router.get("/{attempt_id}", response_model=AttemptResponse)
async def get_attempt(
    attempt_id: UUID,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    attempt = await attempt_service.get_attempt(db, attempt_id)
    if attempt is None or attempt.user_id != user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Attempt not found")
    return attempt


@router.put("/{attempt_id}/answers", response_model=AttemptResponse)
async def submit_answers(
    attempt_id: UUID,
    data: AnswersBatchSubmit,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    attempt = await attempt_service.get_attempt(db, attempt_id)
    if attempt is None or attempt.user_id != user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Attempt not found")
    try:
        return await attempt_service.submit_answers(db, attempt, data.answers)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.post("/{attempt_id}/submit", response_model=AttemptResponse)
async def submit_attempt(
    attempt_id: UUID,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    attempt = await attempt_service.get_attempt(db, attempt_id)
    if attempt is None or attempt.user_id != user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Attempt not found")
    try:
        return await attempt_service.submit_attempt(db, attempt)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.get("/{attempt_id}/review", response_model=AttemptReviewResponse)
async def review_attempt(
    attempt_id: UUID,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    attempt = await attempt_service.get_attempt(db, attempt_id)
    if attempt is None or attempt.user_id != user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Attempt not found")
    review = await attempt_service.get_review(db, attempt)
    return AttemptReviewResponse(attempt=attempt, questions=review["questions"])
