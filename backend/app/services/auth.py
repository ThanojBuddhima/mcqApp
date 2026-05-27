from uuid import UUID

from google.auth.transport import requests as google_requests
from google.oauth2 import id_token
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    verify_password,
)
from app.models import User, UserRole
from app.schemas.auth import GoogleAuthRequest, TokenResponse, UserLogin, UserRegister


class AuthService:
    async def register(self, db: AsyncSession, data: UserRegister) -> User:
        existing = await db.execute(select(User).where(User.email == data.email))
        if existing.scalar_one_or_none():
            raise ValueError("Email already registered")

        user = User(
            email=data.email,
            password_hash=hash_password(data.password),
            display_name=data.name,
            grade=data.grade.value,
            role=UserRole.STUDENT,
        )
        db.add(user)
        await db.flush()
        return user

    async def login(self, db: AsyncSession, data: UserLogin) -> TokenResponse:
        result = await db.execute(select(User).where(User.email == data.email))
        user = result.scalar_one_or_none()
        if user is None or not user.password_hash or not verify_password(data.password, user.password_hash):
            raise ValueError("Invalid email or password")
        return self._tokens(user)

    async def google_login(self, db: AsyncSession, data: GoogleAuthRequest) -> TokenResponse:
        if not settings.google_client_id:
            raise ValueError("Google OAuth not configured")

        idinfo = id_token.verify_oauth2_token(
            data.id_token, google_requests.Request(), settings.google_client_id
        )
        google_sub = idinfo["sub"]
        email = idinfo["email"]
        name = idinfo.get("name", email.split("@")[0])

        result = await db.execute(select(User).where(User.google_id == google_sub))
        user = result.scalar_one_or_none()
        if user is None:
            email_result = await db.execute(select(User).where(User.email == email))
            user = email_result.scalar_one_or_none()
            if user:
                user.google_id = google_sub
            else:
                user = User(email=email, google_id=google_sub, display_name=name, role=UserRole.STUDENT)
                db.add(user)
                await db.flush()
        return self._tokens(user)

    async def refresh(self, db: AsyncSession, refresh_token: str) -> TokenResponse:
        payload = decode_token(refresh_token)
        if payload.get("type") != "refresh":
            raise ValueError("Invalid refresh token")
        user_id = UUID(payload["sub"])
        result = await db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        if user is None:
            raise ValueError("User not found")
        return self._tokens(user)

    def _tokens(self, user: User) -> TokenResponse:
        return TokenResponse(
            access_token=create_access_token(user.id, {"role": user.role.value}),
            refresh_token=create_refresh_token(user.id),
        )


auth_service = AuthService()
