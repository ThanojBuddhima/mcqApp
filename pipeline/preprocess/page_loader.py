import io
from pathlib import Path

import cv2
import fitz
import numpy as np
from PIL import Image

from pipeline.types import PageImage


def load_document_pages(file_bytes: bytes, filename: str, dpi: int = 300) -> list[PageImage]:
    ext = Path(filename).suffix.lower()
    if ext == ".pdf":
        return _pdf_to_pages(file_bytes, dpi)
    return [_image_bytes_to_page(file_bytes, 0)]


def _pdf_to_pages(file_bytes: bytes, dpi: int) -> list[PageImage]:
    pages: list[PageImage] = []
    doc = fitz.open(stream=file_bytes, filetype="pdf")
    zoom = dpi / 72
    matrix = fitz.Matrix(zoom, zoom)
    for i, page in enumerate(doc):
        pix = page.get_pixmap(matrix=matrix, alpha=False)
        img_bytes = pix.tobytes("png")
        pages.append(_image_bytes_to_page(img_bytes, i))
    doc.close()
    return pages


def _image_bytes_to_page(data: bytes, page_index: int) -> PageImage:
    arr = np.frombuffer(data, dtype=np.uint8)
    img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if img is None:
        raise ValueError("Could not decode image")
    h, w = img.shape[:2]
    _, encoded = cv2.imencode(".png", img)
    return PageImage(page_index=page_index, image_bytes=encoded.tobytes(), width=w, height=h)


def preprocess_page(image_bytes: bytes) -> bytes:
    arr = np.frombuffer(image_bytes, dtype=np.uint8)
    img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if img is None:
        return image_bytes

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    gray = cv2.fastNlMeansDenoising(gray, None, 10, 7, 21)

    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    enhanced = clahe.apply(gray)

    coords = np.column_stack(np.where(enhanced > 0))
    if len(coords) > 0:
        angle = cv2.minAreaRect(coords)[-1]
        if angle < -45:
            angle = -(90 + angle)
        else:
            angle = -angle
        if abs(angle) > 0.5:
            h, w = enhanced.shape
            center = (w // 2, h // 2)
            matrix = cv2.getRotationMatrix2D(center, angle, 1.0)
            enhanced = cv2.warpAffine(
                enhanced, matrix, (w, h), flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_REPLICATE
            )

    result = cv2.cvtColor(enhanced, cv2.COLOR_GRAY2BGR)
    _, encoded = cv2.imencode(".webp", result, [cv2.IMWRITE_WEBP_QUALITY, 90])
    return encoded.tobytes()


def crop_region(image_bytes: bytes, bbox: list[int], padding: int = 8) -> bytes:
    arr = np.frombuffer(image_bytes, dtype=np.uint8)
    img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if img is None:
        return image_bytes

    x1, y1, x2, y2 = bbox
    h, w = img.shape[:2]
    x1 = max(0, x1 - padding)
    y1 = max(0, y1 - padding)
    x2 = min(w, x2 + padding)
    y2 = min(h, y2 + padding)
    cropped = img[y1:y2, x1:x2]
    _, encoded = cv2.imencode(".webp", cropped, [cv2.IMWRITE_WEBP_QUALITY, 92])
    return encoded.tobytes()
