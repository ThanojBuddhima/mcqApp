FROM python:3.11-slim

WORKDIR /app

ARG INSTALL_OCR=false

RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1 \
    libglib2.0-0 \
    libgomp1 \
    poppler-utils \
    && rm -rf /var/lib/apt/lists/*

COPY backend/requirements.txt /app/backend/requirements.txt
COPY backend/requirements-ocr.txt /app/backend/requirements-ocr.txt
RUN pip install --no-cache-dir -r /app/backend/requirements.txt \
    && if [ "$INSTALL_OCR" = "true" ]; then pip install --no-cache-dir -r /app/backend/requirements-ocr.txt; fi

COPY backend /app/backend
COPY pipeline /app/pipeline
COPY scripts /app/scripts

ENV PYTHONPATH=/app/backend:/app

WORKDIR /app/backend
