import re
import uuid

from pipeline.types import LayoutBlock, OCRBlockResult, QuestionCluster

QUESTION_START = re.compile(
    r"^(\d{1,2}[\.\)]\s*|[\(\[]?[a-eA-E1-5][\)\]]\s*|[\u0DE6-\u0DEF]+[\.\)]\s*)"
)
OPTION_START = re.compile(r"^[\(\[]?([1-5]|[A-Ea-e]|[\u0D8A-\u0D8F])[\)\]\.\s]")


def segment_questions(
    ocr_blocks: list[OCRBlockResult],
    layout_blocks: list[LayoutBlock],
    y_gap_threshold: int = 80,
) -> list[QuestionCluster]:
    if not ocr_blocks:
        return []

    sorted_blocks = sorted(ocr_blocks, key=lambda b: (b.page_index, b.bbox[1], b.bbox[0]))
    figures = [b for b in layout_blocks if b.block_type == "figure"]

    clusters: list[QuestionCluster] = []
    current: QuestionCluster | None = None

    for block in sorted_blocks:
        is_new_question = bool(QUESTION_START.match(block.text.strip()))
        is_option = bool(OPTION_START.match(block.text.strip()))

        if is_new_question or current is None:
            if current is not None:
                _attach_figures(current, figures)
                clusters.append(current)
            current = QuestionCluster(
                cluster_id=str(uuid.uuid4())[:8],
                page_index=block.page_index,
                question_blocks=[block],
            )
        elif is_option and current is not None:
            current.option_blocks.append(block)
        elif current is not None:
            last_y = current.question_blocks[-1].bbox[3] if current.question_blocks else 0
            gap = block.bbox[1] - last_y
            if gap > y_gap_threshold and not is_option:
                _attach_figures(current, figures)
                clusters.append(current)
                current = QuestionCluster(
                    cluster_id=str(uuid.uuid4())[:8],
                    page_index=block.page_index,
                    question_blocks=[block],
                )
            elif is_option:
                current.option_blocks.append(block)
            else:
                current.question_blocks.append(block)

    if current is not None:
        _attach_figures(current, figures)
        clusters.append(current)

    return clusters


def _attach_figures(cluster: QuestionCluster, figures: list[LayoutBlock]) -> None:
    if not cluster.question_blocks:
        return
    q_y1 = min(b.bbox[1] for b in cluster.question_blocks)
    q_y2 = max(b.bbox[3] for b in cluster.question_blocks + cluster.option_blocks)

    for fig in figures:
        if fig.page_index != cluster.page_index:
            continue
        fig_y = fig.bbox[1]
        if q_y1 - 20 <= fig_y <= q_y2 + 120:
            cluster.figure_blocks.append(fig)
