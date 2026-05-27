import json
import re
from typing import Any

from pipeline.types import QuestionCluster


def parse_clusters_to_quiz(
    clusters: list[QuestionCluster],
    title: str = "Imported Quiz",
    metadata: dict | None = None,
) -> dict[str, Any]:
    questions = []
    for i, cluster in enumerate(clusters):
        question_text = "\n".join(b.text for b in cluster.question_blocks).strip()
        options = _extract_options(cluster)
        q_type = "mcq" if options else "structured"
        figure_url = cluster.figure_urls[0] if cluster.figure_urls else None

        questions.append(
            {
                "id": cluster.cluster_id,
                "order": i + 1,
                "type": q_type,
                "questionText": question_text,
                "questionImage": figure_url,
                "layoutRefs": {
                    "pageIndex": cluster.page_index,
                    "blockIds": [b.block_id for b in cluster.question_blocks],
                },
                "options": options,
                "correctAnswer": "",
                "marks": 1,
                "explanation": "",
                "difficulty": "medium",
            }
        )

    return {
        "quizTitle": title,
        "metadata": metadata or {"sourceType": "uploaded_paper", "language": ["si", "en"]},
        "settings": {"timeLimitMinutes": 60, "totalMarks": len(questions), "showAnswersAfter": True},
        "questions": questions,
    }


def _extract_options(cluster: QuestionCluster) -> list[dict]:
    options = []
    for block in cluster.option_blocks:
        match = re.match(r"^[\(\[]?([1-5A-Ea-e\u0D8A-\u0D8F])[\)\]\.\s]*(.*)$", block.text.strip(), re.DOTALL)
        if match:
            label = match.group(1)
            text = match.group(2).strip()
        else:
            label = str(len(options) + 1)
            text = block.text.strip()
        options.append({"id": label, "text": text, "image": None, "isCorrect": False})
    return options


async def parse_with_ai(clusters: list[QuestionCluster], gemini_api_key: str | None = None) -> dict[str, Any]:
    return parse_with_ai_sync(clusters, gemini_api_key)


def parse_with_ai_sync(
    clusters: list[QuestionCluster],
    gemini_api_key: str | None = None,
    title: str = "Imported Quiz",
) -> dict[str, Any]:
    base = parse_clusters_to_quiz(clusters, title=title)
    if not gemini_api_key:
        return base

    try:
        import google.generativeai as genai

        genai.configure(api_key=gemini_api_key)
        model = genai.GenerativeModel("gemini-2.0-flash")
        prompt = f"""Parse these exam question clusters into structured quiz JSON.
Preserve Sinhala text exactly. Infer MCQ type and map options.
Return valid JSON matching this schema keys: quizTitle, questions (with questionText, type, options, correctAnswer).
Clusters:
{json.dumps(base, ensure_ascii=False)}"""
        response = model.generate_content(prompt)
        text = (response.text or "").replace("```json", "").replace("```", "").strip()
        return json.loads(text)
    except Exception:
        return base
