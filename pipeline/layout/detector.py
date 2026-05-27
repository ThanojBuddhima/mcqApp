"""Layout detection — heuristic fallback when DocLayout-YOLO is unavailable."""

import re
import uuid

import cv2
import numpy as np

from pipeline.types import LayoutBlock, PageImage


def detect_layout_heuristic(page: PageImage) -> list[LayoutBlock]:
    """Fallback layout detector using contour analysis."""
    arr = np.frombuffer(page.image_bytes, dtype=np.uint8)
    img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if img is None:
        return [_full_page_text_block(page)]

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    _, binary = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)

    blocks: list[LayoutBlock] = []
    contours, _ = cv2.findContours(binary, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    for contour in contours:
        x, y, w, h = cv2.boundingRect(contour)
        area = w * h
        if area < 2000 or w < 30 or h < 15:
            continue

        aspect = w / max(h, 1)
        block_type = "figure" if 0.5 < aspect < 2.0 and area > 15000 else "text"
        blocks.append(
            LayoutBlock(
                block_id=str(uuid.uuid4())[:8],
                page_index=page.page_index,
                block_type=block_type,
                bbox=[x, y, x + w, y + h],
                confidence=0.6,
            )
        )

    blocks.sort(key=lambda b: (b.bbox[1], b.bbox[0]))
    if not blocks:
        return [_full_page_text_block(page)]
    return blocks


def _full_page_text_block(page: PageImage) -> LayoutBlock:
    return LayoutBlock(
        block_id=str(uuid.uuid4())[:8],
        page_index=page.page_index,
        block_type="text",
        bbox=[0, 0, page.width, page.height],
        confidence=0.5,
    )


def detect_layout(page: PageImage) -> list[LayoutBlock]:
    try:
        from pipeline.layout.doclayout import detect_with_doclayout

        return detect_with_doclayout(page)
    except Exception:
        return detect_layout_heuristic(page)
