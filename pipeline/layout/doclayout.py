"""DocLayout-YOLO integration (optional — requires model weights)."""

from pipeline.types import LayoutBlock, PageImage


def detect_with_doclayout(page: PageImage) -> list[LayoutBlock]:
    raise NotImplementedError(
        "DocLayout-YOLO model not bundled. Using heuristic fallback. "
        "Install model weights to enable."
    )
