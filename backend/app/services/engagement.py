from uuid import UUID

import redis.asyncio as aioredis
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.config import settings
from app.models import Favorite, Quiz, QuizAttempt, AttemptStatus


class FavoriteService:
    async def add(self, db: AsyncSession, user_id: UUID, quiz_id: UUID) -> Favorite:
        existing = await db.execute(
            select(Favorite).where(Favorite.user_id == user_id, Favorite.quiz_id == quiz_id)
        )
        fav = existing.scalar_one_or_none()
        if fav:
            return fav
        fav = Favorite(user_id=user_id, quiz_id=quiz_id)
        db.add(fav)
        await db.flush()
        return fav

    async def remove(self, db: AsyncSession, user_id: UUID, quiz_id: UUID) -> bool:
        result = await db.execute(
            select(Favorite).where(Favorite.user_id == user_id, Favorite.quiz_id == quiz_id)
        )
        fav = result.scalar_one_or_none()
        if fav is None:
            return False
        await db.delete(fav)
        await db.flush()
        return True

    async def list_for_user(self, db: AsyncSession, user_id: UUID) -> list[Quiz]:
        result = await db.execute(
            select(Quiz)
            .join(Favorite, Favorite.quiz_id == Quiz.id)
            .options(selectinload(Quiz.questions))
            .where(Favorite.user_id == user_id)
            .order_by(Favorite.created_at.desc())
        )
        return list(result.scalars().unique().all())


class LeaderboardService:
    def __init__(self) -> None:
        self._redis: aioredis.Redis | None = None

    async def _client(self) -> aioredis.Redis:
        if self._redis is None:
            self._redis = aioredis.from_url(settings.redis_url, decode_responses=True)
        return self._redis

    def _key(self, quiz_id: UUID) -> str:
        return f"leaderboard:quiz:{quiz_id}"

    async def update_score(self, db: AsyncSession, attempt) -> None:
        if attempt.status != AttemptStatus.SUBMITTED or attempt.score is None:
            return
        client = await self._client()
        await client.zadd(self._key(attempt.quiz_id), {str(attempt.user_id): attempt.score})

    async def get_quiz_leaderboard(self, quiz_id: UUID, limit: int = 20) -> list[dict]:
        client = await self._client()
        entries = await client.zrevrange(self._key(quiz_id), 0, limit - 1, withscores=True)
        return [{"user_id": uid, "score": int(score), "rank": i + 1} for i, (uid, score) in enumerate(entries)]

    async def rebuild_quiz(self, db: AsyncSession, quiz_id: UUID) -> None:
        client = await self._client()
        await client.delete(self._key(quiz_id))
        result = await db.execute(
            select(QuizAttempt).where(
                QuizAttempt.quiz_id == quiz_id,
                QuizAttempt.status == AttemptStatus.SUBMITTED,
                QuizAttempt.score.isnot(None),
            )
        )
        for attempt in result.scalars().all():
            best_key = f"leaderboard:best:{quiz_id}:{attempt.user_id}"
            current_best = await client.get(best_key)
            if current_best is None or attempt.score > int(current_best):
                await client.set(best_key, attempt.score)
                await client.zadd(self._key(quiz_id), {str(attempt.user_id): attempt.score})


favorite_service = FavoriteService()
leaderboard_service = LeaderboardService()
