# System Architecture

## Overview

The MCQ Platform converts scanned Sri Lankan exam papers into interactive online quizzes while preserving layout, images, and Sinhala/English text.

## Components

```
Flutter App  →  FastAPI  →  PostgreSQL
                  ↓
              Celery Worker
                  ↓
         Pipeline (OpenCV → Layout → PaddleOCR → AI)
                  ↓
              MinIO/S3
```

## OCR Pipeline (PaddleOCR)

1. **Preprocess** — deskew, denoise, CLAHE (OpenCV)
2. **Layout** — DocLayout-YOLO or heuristic contour detection
3. **OCR** — PaddleOCR per text block (`lang=en`, `lang=si`)
4. **Segment** — cluster blocks into questions by numbering patterns
5. **Crop** — extract figure/diagram regions from original page
6. **Parse** — Gemini structured JSON (fallback: rule-based parser)
7. **Review** — tutor edits draft quiz before publish

## Database

Core tables: `users`, `quizzes`, `questions`, `question_options`, `quiz_attempts`, `document_jobs`, `past_papers`, `classes`, `marketplace_items`.

## Roles

- **Student** — attempt quizzes, review answers, browse past papers
- **Tutor** — create/edit quizzes, upload papers, manage classes
- **Admin** — import past papers, manage users

## Deployment

- **Dev**: Docker Compose (Postgres, Redis, MinIO, API, Worker)
- **Prod**: AWS/DigitalOcean with managed Postgres, S3, Redis, Celery workers

See the full plan in `.cursor/plans/` for the 18-step implementation roadmap.
