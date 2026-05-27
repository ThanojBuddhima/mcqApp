"""Main document processing orchestrator."""

from typing import Callable

from pipeline.ai_parse.quiz_parser import parse_clusters_to_quiz, parse_with_ai_sync
from pipeline.layout.detector import detect_layout
from pipeline.ocr.paddle_engine import paddle_engine
from pipeline.preprocess.page_loader import crop_region, load_document_pages, preprocess_page
from pipeline.segment.question_segmenter import segment_questions
from pipeline.types import PageImage

ProgressCallback = Callable[[str, int], None]


class DocumentProcessor:
    def __init__(
        self,
        upload_fn: Callable[[str, bytes, str], str],
        gemini_api_key: str | None = None,
    ) -> None:
        self.upload_fn = upload_fn
        self.gemini_api_key = gemini_api_key

    def process(
        self,
        file_bytes: bytes,
        filename: str,
        job_id: str,
        on_progress: ProgressCallback | None = None,
    ) -> dict:
        def progress(stage: str, pct: int) -> None:
            if on_progress:
                on_progress(stage, pct)

        progress("preprocessing", 10)
        pages = load_document_pages(file_bytes, filename)
        processed_pages: list[PageImage] = []

        for page in pages:
            processed_bytes = preprocess_page(page.image_bytes)
            self.upload_fn(f"jobs/{job_id}/pages/{page.page_index}.webp", processed_bytes, "image/webp")
            processed_pages.append(
                PageImage(
                    page_index=page.page_index,
                    image_bytes=processed_bytes,
                    width=page.width,
                    height=page.height,
                )
            )

        progress("layout", 30)
        all_layout = []
        all_ocr = []

        for page in processed_pages:
            layout_blocks = detect_layout(page)
            all_layout.extend(layout_blocks)
            ocr_results = paddle_engine.recognize_page_blocks(page, layout_blocks)
            all_ocr.extend(ocr_results)

        progress("ocr", 55)
        progress("segmentation", 70)
        clusters = segment_questions(all_ocr, all_layout)

        for cluster in clusters:
            for fig in cluster.figure_blocks:
                crop = crop_region(processed_pages[cluster.page_index].image_bytes, fig.bbox)
                url = self.upload_fn(f"jobs/{job_id}/figures/{fig.block_id}.webp", crop, "image/webp")
                cluster.figure_urls.append(url)

        progress("ai_parse", 85)
        quiz_json = parse_with_ai_sync(clusters, self.gemini_api_key, title=filename)

        progress("done", 100)
        return {
            "quiz_json": quiz_json,
            "page_count": len(processed_pages),
            "clusters_count": len(clusters),
            "ocr_blocks_count": len(all_ocr),
        }
