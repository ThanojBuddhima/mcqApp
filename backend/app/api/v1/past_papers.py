from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user, require_admin
from app.models import User
from app.schemas.past_paper import PastPaperCreate, PastPaperResponse, SubjectResponse
from app.services.past_paper import past_paper_service

router = APIRouter()


@router.get("/subjects", response_model=list[SubjectResponse])
async def list_subjects(db: AsyncSession = Depends(get_db)):
    return await past_paper_service.list_subjects(db)


@router.get("", response_model=list[PastPaperResponse])
async def list_past_papers(
    grade: str | None = None,
    subject_id: UUID | None = None,
    medium: str | None = None,
    year: int | None = None,
    exam_type: str | None = None,
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return await past_paper_service.list_papers(
        db,
        grade=grade,
        subject_id=subject_id,
        medium=medium,
        year=year,
        exam_type=exam_type,
        skip=skip,
        limit=limit,
    )


@router.get("/{paper_id}", response_model=PastPaperResponse)
async def get_past_paper(
    paper_id: UUID,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    paper = await past_paper_service.get_by_id(db, paper_id)
    if paper is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Past paper not found")
    return paper


@router.post("", response_model=PastPaperResponse, status_code=status.HTTP_201_CREATED)
async def create_past_paper(
    data: PastPaperCreate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(require_admin),
):
    return await past_paper_service.create(db, data)
