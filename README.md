# MCQ Platform — Sri Lankan AI EdTech

AI-powered education platform for Sri Lankan students and tutors. Upload exam papers (photo/PDF) and convert them into interactive quizzes with **PaddleOCR** (Sinhala + English), preserved diagrams, and tutor editing tools.

## Repository Structure

```
mcq/
├── backend/          # FastAPI REST API
├── pipeline/         # OCR & document processing (PaddleOCR, OpenCV)
├── mobile/           # Flutter app (iOS, Android, Web)
├── scripts/          # Seed & utility scripts
├── docs/             # Architecture & API docs
└── docker-compose.yml
```

## Tech Stack

| Layer | Technology |
|-------|------------|
| Frontend | Flutter + Riverpod + go_router |
| Backend | FastAPI + SQLAlchemy + Celery |
| Database | PostgreSQL 16 |
| Cache/Queue | Redis |
| Storage | MinIO (dev) / S3 (prod) |
| OCR | **PaddleOCR** (Sinhala + English) |
| Layout | DocLayout-YOLO + heuristic fallback |
| AI | Gemini API |

## Quick Start

### 1. Clone & configure

```bash
cp .env.example .env
# Edit .env — set JWT_SECRET_KEY, optionally GEMINI_API_KEY
```

### 2. Start infrastructure

```bash
docker compose up -d postgres redis minio minio-init
```

### 3. Backend (recommended: Docker)

```bash
docker compose up -d --build api worker
```

API docs: http://localhost:8000/docs

### 3b. Backend (local dev — requires Python 3.11 or 3.12)

Python 3.14+ is not yet supported by all dependencies. Use pyenv or Docker.

```bash
cd backend
python3.11 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
export PYTHONPATH="../backend:.."
uvicorn app.main:app --reload --port 8000
```

### 4. Celery worker

```bash
cd backend
celery -A app.workers.celery_app worker --loglevel=info
```

### 5. Seed demo data

```bash
python scripts/seed.py
```

### 6. Flutter app

```bash
cd mobile
flutter pub get
flutter run
```

### Full Docker stack

```bash
docker compose up --build
```

API docs: http://localhost:8000/docs

## Demo Accounts

| Role | Email | Password |
|------|-------|----------|
| Tutor | tutor@demo.lk | demo1234 |
| Student | student@demo.lk | demo1234 |

## Paper-to-Quiz Pipeline

```
Upload → OpenCV Preprocess → Layout Detection → PaddleOCR →
Question Segmentation → Figure Crop → AI Parse → Draft Quiz → Tutor Review
```

## API Overview

- `POST /api/v1/auth/register|login|google`
- `POST /api/v1/documents/upload` — upload paper, triggers OCR job
- `GET /api/v1/documents/jobs/{id}` — job progress
- `POST /api/v1/quizzes` — create/edit quizzes
- `POST /api/v1/quizzes/{id}/attempts` — start quiz attempt
- `GET /api/v1/past-papers` — browse past papers
- `POST /api/v1/ai/*` — AI study tools

See [docs/architecture.md](docs/architecture.md) for full system design.

## PaddleOCR Setup

PaddleOCR is required for production OCR. Install in the worker environment:

```bash
pip install paddlepaddle paddleocr
```

Models download automatically on first run (`en` and `si`).

## License

Proprietary — All rights reserved.
