from fastapi import APIRouter, Depends

from app.core.deps import get_current_user
from app.models import User
from app.schemas.ai import (
    AdjustDifficultyRequest,
    ChatRequest,
    ExplainAnswerRequest,
    FlashcardRequest,
    GenerateMCQsRequest,
    SummarizeRequest,
)
from app.services.ai import ai_service

router = APIRouter()


@router.post("/generate-mcqs")
async def generate_mcqs(data: GenerateMCQsRequest, user: User = Depends(get_current_user)):
    return await ai_service.generate_mcqs(data.source_text, data.count, data.language, data.subject)


@router.post("/explain-answer")
async def explain_answer(data: ExplainAnswerRequest, user: User = Depends(get_current_user)):
    return await ai_service.explain_answer(
        data.question_text, data.correct_answer, data.user_answer, data.language
    )


@router.post("/summarize")
async def summarize(data: SummarizeRequest, user: User = Depends(get_current_user)):
    return await ai_service.summarize(data.source_text, data.language)


@router.post("/flashcards")
async def flashcards(data: FlashcardRequest, user: User = Depends(get_current_user)):
    return await ai_service.generate_flashcards(data.source_text, data.count)


@router.post("/chat")
async def chat(data: ChatRequest, user: User = Depends(get_current_user)):
    messages = [{"role": m.role, "content": m.content} for m in data.messages]
    return await ai_service.chat(messages, data.language)


@router.post("/adjust-difficulty")
async def adjust_difficulty(data: AdjustDifficultyRequest, user: User = Depends(get_current_user)):
    return await ai_service.adjust_difficulty(
        data.question_text, data.options, data.target_difficulty, data.language
    )
