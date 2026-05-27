.PHONY: up down api worker seed test flutter

up:
	docker compose up -d postgres redis minio minio-init

down:
	docker compose down

api:
	cd backend && source .venv/bin/activate && PYTHONPATH=.. uvicorn app.main:app --reload --port 8000

worker:
	cd backend && source .venv/bin/activate && PYTHONPATH=.. celery -A app.workers.celery_app worker --loglevel=info

seed:
	cd backend && source .venv/bin/activate && PYTHONPATH=.. python ../scripts/seed.py

test:
	cd backend && source .venv/bin/activate && PYTHONPATH=.. pytest tests/ -v

flutter:
	cd mobile && flutter run
