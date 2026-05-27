from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user, require_tutor
from app.models import User
from app.schemas.engagement import ClassCreate, ClassResponse, EnrollRequest, EnrollmentResponse, StudentAnalytics
from app.services.class_service import analytics_service, class_service

router = APIRouter()


@router.post("", response_model=ClassResponse, status_code=status.HTTP_201_CREATED)
async def create_class(
    data: ClassCreate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(require_tutor),
):
    return await class_service.create(db, user.id, data.name, data.description)


@router.get("", response_model=list[ClassResponse])
async def list_classes(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(require_tutor),
):
    return await class_service.list_for_tutor(db, user.id)


@router.post("/enroll", response_model=EnrollmentResponse)
async def enroll_in_class(
    data: EnrollRequest,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    try:
        return await class_service.enroll_by_code(db, user.id, data.enrollment_code)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.get("/me/analytics", response_model=StudentAnalytics)
async def my_analytics(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return await analytics_service.student_dashboard(db, user.id)


@router.get("/{class_id}/analytics")
async def class_analytics(
    class_id: UUID,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(require_tutor),
):
    cls = await class_service.get_by_id(db, class_id)
    if cls is None or cls.tutor_id != user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Class not found")
    return await class_service.get_analytics(db, class_id)
