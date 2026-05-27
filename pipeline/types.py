from dataclasses import dataclass, field


@dataclass
class PageImage:
    page_index: int
    image_bytes: bytes
    width: int
    height: int


@dataclass
class LayoutBlock:
    block_id: str
    page_index: int
    block_type: str
    bbox: list[int]
    confidence: float = 1.0


@dataclass
class OCRBlockResult:
    block_id: str
    page_index: int
    bbox: list[int]
    text: str
    confidence: float
    lang: str
    needs_review: bool = False


@dataclass
class QuestionCluster:
    cluster_id: str
    page_index: int
    question_blocks: list[OCRBlockResult] = field(default_factory=list)
    figure_blocks: list[LayoutBlock] = field(default_factory=list)
    option_blocks: list[OCRBlockResult] = field(default_factory=list)
    figure_urls: list[str] = field(default_factory=list)
