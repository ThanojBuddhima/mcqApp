from fastapi import APIRouter

from app.api.v1 import admin, ai, attempts, auth, classes, documents, engagement, health, past_papers, quizzes

api_router = APIRouter()
api_router.include_router(health.router, tags=["health"])
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(admin.router, prefix="/admin", tags=["admin"])
api_router.include_router(quizzes.router, prefix="/quizzes", tags=["quizzes"])
api_router.include_router(engagement.router, prefix="/quizzes", tags=["engagement"])
api_router.include_router(attempts.router, prefix="/attempts", tags=["attempts"])
api_router.include_router(documents.router, prefix="/documents", tags=["documents"])
api_router.include_router(past_papers.router, prefix="/past-papers", tags=["past-papers"])
api_router.include_router(classes.router, prefix="/classes", tags=["classes"])
api_router.include_router(ai.router, prefix="/ai", tags=["ai"])
