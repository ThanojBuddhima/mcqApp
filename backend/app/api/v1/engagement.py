from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user, require_tutor
from app.models import User
from app.schemas.engagement import LeaderboardEntry
from app.schemas.quiz import QuizResponse
from app.services.engagement import favorite_service, leaderboard_service

router = APIRouter()


@router.post("/{quiz_id}/favorite", status_code=status.HTTP_201_CREATED)
async def add_favorite(
    quiz_id: UUID,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    await favorite_service.add(db, user.id, quiz_id)
    return {"message": "Added to favorites"}


@router.delete("/{quiz_id}/favorite", status_code=status.HTTP_204_NO_CONTENT)
async def remove_favorite(
    quiz_id: UUID,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    removed = await favorite_service.remove(db, user.id, quiz_id)
    if not removed:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Favorite not found")


@router.get("/favorites/list", response_model=list[QuizResponse])
async def list_favorites(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return await favorite_service.list_for_user(db, user.id)


@router.get("/{quiz_id}/leaderboard", response_model=list[LeaderboardEntry])
async def quiz_leaderboard(
    quiz_id: UUID,
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    entries = await leaderboard_service.get_quiz_leaderboard(quiz_id, limit)
    if not entries:
        await leaderboard_service.rebuild_quiz(db, quiz_id)
        entries = await leaderboard_service.get_quiz_leaderboard(quiz_id, limit)

    enriched = []
    for entry in entries:
        user_result = await db.execute(select(User).where(User.id == UUID(entry["user_id"])))
        u = user_result.scalar_one_or_none()
        enriched.append(
            LeaderboardEntry(
                user_id=entry["user_id"],
                score=entry["score"],
                rank=entry["rank"],
                display_name=u.display_name if u else None,
            )
        )
    return enriched
