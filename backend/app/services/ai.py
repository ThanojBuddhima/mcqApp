import json
from typing import Any

from app.core.config import settings


class AIService:
    """AI service using Gemini API with graceful fallback when not configured."""

    def __init__(self) -> None:
        self._model = None
        if settings.gemini_api_key:
            try:
                import google.generativeai as genai

                genai.configure(api_key=settings.gemini_api_key)
                self._model = genai.GenerativeModel("gemini-2.0-flash")
            except Exception:
                self._model = None

    async def _generate(self, prompt: str) -> str:
        if self._model is None:
            return json.dumps({"message": "AI not configured. Set GEMINI_API_KEY.", "fallback": True})
        response = self._model.generate_content(prompt)
        return response.text or ""

    async def generate_mcqs(
        self, source_text: str, count: int = 5, language: str = "sinhala", subject: str | None = None
    ) -> dict[str, Any]:
        prompt = f"""Generate {count} MCQ questions in {language} from this text.
Subject: {subject or 'General'}
Return valid JSON: {{"questions": [{{"questionText":"","options":["","","",""],"correctAnswer":"A","explanation":""}}]}}

Text:
{source_text}
"""
        text = await self._generate(prompt)
        try:
            return json.loads(text.replace("```json", "").replace("```", "").strip())
        except json.JSONDecodeError:
            return {"questions": [], "raw": text}

    async def explain_answer(
        self,
        question_text: str,
        correct_answer: str,
        user_answer: str | None = None,
        language: str = "sinhala",
    ) -> dict[str, str]:
        prompt = f"""Explain the correct answer in {language} for Sri Lankan students.
Question: {question_text}
Correct answer: {correct_answer}
Student answer: {user_answer or 'Not provided'}
Provide a clear step-by-step explanation."""
        text = await self._generate(prompt)
        return {"explanation": text}

    async def summarize(self, source_text: str, language: str = "sinhala") -> dict[str, str]:
        prompt = f"Summarize the following study notes in {language} for Sri Lankan students:\n\n{source_text}"
        text = await self._generate(prompt)
        return {"summary": text}

    async def generate_flashcards(
        self, source_text: str | None = None, count: int = 10
    ) -> dict[str, Any]:
        prompt = f"""Create {count} flashcards as JSON:
{{"flashcards": [{{"front":"","back":""}}]}}
From:
{source_text or ''}"""
        text = await self._generate(prompt)
        try:
            return json.loads(text.replace("```json", "").replace("```", "").strip())
        except json.JSONDecodeError:
            return {"flashcards": [], "raw": text}

    async def chat(self, messages: list[dict], language: str = "sinhala") -> dict[str, str]:
        history = "\n".join(f"{m['role']}: {m['content']}" for m in messages)
        prompt = f"You are a Sri Lankan study assistant. Respond in {language}.\n\n{history}"
        text = await self._generate(prompt)
        return {"reply": text}

    async def adjust_difficulty(
        self,
        question_text: str,
        options: list[str],
        target_difficulty: str = "medium",
        language: str = "sinhala",
    ) -> dict[str, Any]:
        prompt = f"""Rewrite this MCQ at {target_difficulty} difficulty in {language}.
Return JSON: {{"questionText":"","options":[],"correctAnswer":""}}
Question: {question_text}
Options: {options}"""
        text = await self._generate(prompt)
        try:
            return json.loads(text.replace("```json", "").replace("```", "").strip())
        except json.JSONDecodeError:
            return {"raw": text}


ai_service = AIService()
