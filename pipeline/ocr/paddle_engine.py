"""PaddleOCR engine — sole OCR provider for Sinhala + English."""

import re
import unicodedata
from functools import lru_cache

import cv2
import numpy as np

from pipeline.types import LayoutBlock, OCRBlockResult, PageImage

SINHALA_RANGE = re.compile(r"[\u0D80-\u0DFF]")


def detect_language_hint(text: str) -> str:
    if not text:
        return "en"
    sinhala_chars = len(SINHALA_RANGE.findall(text))
    total_alpha = len(re.findall(r"\w", text, re.UNICODE)) or 1
    ratio = sinhala_chars / total_alpha
    if ratio > 0.3:
        return "si"
    if ratio > 0.05:
        return "mixed"
    return "en"


@lru_cache(maxsize=1)
def _get_paddle_engines():
    try:
        from paddleocr import PaddleOCR

        en = PaddleOCR(lang="en", use_angle_cls=True, show_log=False)
        si = PaddleOCR(lang="si", use_angle_cls=True, show_log=False)
        return en, si
    except ImportError:
        return None, None
    except Exception:
        return None, None


class PaddleOCREngine:
    CONFIDENCE_THRESHOLD = 0.70

    def recognize_page_blocks(
        self, page: PageImage, layout_blocks: list[LayoutBlock]
    ) -> list[OCRBlockResult]:
        text_blocks = [b for b in layout_blocks if b.block_type in ("text", "list", "title", "option_block")]
        if not text_blocks:
            text_blocks = [b for b in layout_blocks if b.block_type != "figure"]

        results: list[OCRBlockResult] = []
        for block in text_blocks:
            result = self.recognize_block(page, block)
            if result.text.strip():
                results.append(result)
        return results

    def recognize_block(self, page: PageImage, block: LayoutBlock) -> OCRBlockResult:
        crop = _crop_block(page.image_bytes, block.bbox)
        en_engine, si_engine = _get_paddle_engines()

        if en_engine is None:
            return OCRBlockResult(
                block_id=block.block_id,
                page_index=block.page_index,
                bbox=block.bbox,
                text="[OCR unavailable — install paddleocr]",
                confidence=0.0,
                lang="unknown",
                needs_review=True,
            )

        en_lines = _run_ocr(en_engine, crop)
        si_lines = _run_ocr(si_engine, crop)

        merged_text, confidence, lang = _merge_ocr_results(en_lines, si_lines)
        lang_hint = detect_language_hint(merged_text) if merged_text else lang

        return OCRBlockResult(
            block_id=block.block_id,
            page_index=block.page_index,
            bbox=block.bbox,
            text=normalize_sinhala_text(merged_text),
            confidence=confidence,
            lang=lang_hint,
            needs_review=confidence < self.CONFIDENCE_THRESHOLD,
        )


def _crop_block(image_bytes: bytes, bbox: list[int]) -> np.ndarray:
    arr = np.frombuffer(image_bytes, dtype=np.uint8)
    img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    x1, y1, x2, y2 = bbox
    return img[y1:y2, x1:x2]


def _run_ocr(engine, crop: np.ndarray) -> list[tuple[str, float, list]]:
    if crop.size == 0:
        return []
    try:
        result = engine.ocr(crop, cls=True)
    except Exception:
        return []
    if not result or not result[0]:
        return []
    lines = []
    for line in result[0]:
        text = line[1][0]
        conf = float(line[1][1])
        bbox = line[0]
        lines.append((text, conf, bbox))
    return lines


def _merge_ocr_results(
    en_lines: list[tuple[str, float, list]], si_lines: list[tuple[str, float, list]]
) -> tuple[str, float, str]:
    if not en_lines and not si_lines:
        return "", 0.0, "unknown"

    en_avg = sum(c for _, c, _ in en_lines) / max(len(en_lines), 1)
    si_avg = sum(c for _, c, _ in si_lines) / max(len(si_lines), 1)

    if si_avg > en_avg and si_lines:
        text = "\n".join(t for t, _, _ in si_lines)
        return text, si_avg, "si"
    if en_lines:
        text = "\n".join(t for t, _, _ in en_lines)
        return text, en_avg, "en"
    text = "\n".join(t for t, _, _ in si_lines)
    return text, si_avg, "si"


def normalize_sinhala_text(text: str) -> str:
    return unicodedata.normalize("NFC", text.strip())


paddle_engine = PaddleOCREngine()
