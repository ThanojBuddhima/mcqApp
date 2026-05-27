from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import require_admin
from app.models import User
from app.schemas.admin import (
    AdminAttemptItem,
    AdminDocumentJobItem,
    AdminOverviewResponse,
    AdminQuizItem,
    AdminUserItem,
    AdminUserListResponse,
    AdminUserUpdate,
)
from app.services.admin_service import admin_service

router = APIRouter()


@router.get("/overview", response_model=AdminOverviewResponse)
async def get_overview(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(require_admin),
):
    return await admin_service.overview(db)


@router.get("/users", response_model=AdminUserListResponse)
async def list_users(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(require_admin),
):
    data = await admin_service.list_users(db, skip=skip, limit=limit)
    return {"items": data["items"], "total": data["total"]}


@router.patch("/users/{user_id}", response_model=AdminUserItem)
async def update_user(
    user_id: UUID,
    data: AdminUserUpdate,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(require_admin),
):
    if user_id == admin.id and data.is_active is False:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot deactivate your own account")
    try:
        user = await admin_service.update_user(db, user_id, data.role, data.is_active)
        return user
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc


@router.get("/document-jobs", response_model=list[AdminDocumentJobItem])
async def list_document_jobs(
    limit: int = Query(50, ge=1, le=200),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(require_admin),
):
    return await admin_service.list_document_jobs(db, limit=limit)


@router.get("/quizzes", response_model=list[AdminQuizItem])
async def list_quizzes(
    limit: int = Query(50, ge=1, le=200),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(require_admin),
):
    return await admin_service.list_quizzes(db, limit=limit)


@router.get("/attempts", response_model=list[AdminAttemptItem])
async def list_attempts(
    limit: int = Query(50, ge=1, le=200),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(require_admin),
):
    return await admin_service.list_attempts(db, limit=limit)
