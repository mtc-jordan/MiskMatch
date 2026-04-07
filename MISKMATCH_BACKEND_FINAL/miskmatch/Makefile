# ─────────────────────────────────────────────────────────────────────────────
# MiskMatch — Developer Makefile
# "Sealed with musk." — Quran 83:26
# ─────────────────────────────────────────────────────────────────────────────

.PHONY: help up down logs migrate migrate-down seed test lint fmt check db-shell redis-shell

# ── Config ────────────────────────────────────────────────────────────────────
export DATABASE_URL         := postgresql+asyncpg://miskmatch:miskmatch@localhost:5432/miskmatch
export DATABASE_URL_SYNC    := postgresql+psycopg2://miskmatch:miskmatch@localhost:5432/miskmatch
export REDIS_URL            := redis://localhost:6379/0
export SECRET_KEY           := dev-secret-key-change-in-production-please

PYTHON   := python
ALEMBIC  := alembic
PYTEST   := pytest

# ── Help ──────────────────────────────────────────────────────────────────────
help:
	@echo ""
	@echo "  MiskMatch Development Commands"
	@echo "  ══════════════════════════════"
	@echo ""
	@echo "  Docker:"
	@echo "    make up            Start postgres + redis + api"
	@echo "    make down          Stop all containers"
	@echo "    make logs          Tail API logs"
	@echo ""
	@echo "  Database:"
	@echo "    make migrate       Run all pending migrations"
	@echo "    make migrate-down  Rollback last migration"
	@echo "    make migrate-new   Create a new migration file"
	@echo "    make seed          Seed development data"
	@echo "    make seed-reset    Truncate tables then re-seed"
	@echo "    make db-shell      Open psql shell"
	@echo ""
	@echo "  Development:"
	@echo "    make dev           Run API locally (no Docker)"
	@echo "    make test          Run all tests"
	@echo "    make test-cov      Run tests with coverage report"
	@echo "    make lint          Run ruff linter"
	@echo "    make fmt           Format code with black + isort"
	@echo "    make check         lint + test"
	@echo ""

# ── Docker ────────────────────────────────────────────────────────────────────
up:
	docker compose up -d postgres redis
	@echo "✓ Postgres + Redis started. Run 'make migrate && make seed' to initialize."

down:
	docker compose down

up-all:
	docker compose up -d

logs:
	docker compose logs -f api

# ── Database ──────────────────────────────────────────────────────────────────
migrate:
	@echo "Running migrations..."
	$(ALEMBIC) upgrade head
	@echo "✓ Migrations complete"

migrate-down:
	$(ALEMBIC) downgrade -1

migrate-new:
	@read -p "Migration name (e.g. add_user_preferences): " name; \
	$(ALEMBIC) revision --autogenerate -m "$$name"

migrate-sql:
	$(ALEMBIC) upgrade head --sql

seed:
	@echo "Seeding development data..."
	$(PYTHON) scripts/seed.py
	@echo "✓ Seed complete"

seed-reset:
	@echo "Resetting and re-seeding..."
	$(PYTHON) scripts/seed.py --reset

db-shell:
	docker exec -it miskmatch_postgres psql -U miskmatch -d miskmatch

redis-shell:
	docker exec -it miskmatch_redis redis-cli

# ── Development ───────────────────────────────────────────────────────────────
dev:
	uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload --log-level info

dev-worker:
	celery -A app.worker.celery_app worker --loglevel=info --concurrency=2

# ── Testing ───────────────────────────────────────────────────────────────────
test:
	$(PYTEST) tests/ -v --tb=short

test-cov:
	$(PYTEST) tests/ -v --tb=short --cov=app --cov-report=term-missing --cov-report=html

test-fast:
	$(PYTEST) tests/ -v --tb=short -x -q

# ── Code Quality ──────────────────────────────────────────────────────────────
lint:
	ruff check app/ tests/

fmt:
	black app/ tests/ scripts/
	isort app/ tests/ scripts/

check: lint test

# ── Setup ─────────────────────────────────────────────────────────────────────
install:
	pip install -r requirements.txt

install-dev:
	pip install -r requirements.txt -r requirements-dev.txt

# ── Full local setup (first time) ─────────────────────────────────────────────
setup: up
	@sleep 3
	$(MAKE) migrate
	$(MAKE) seed
	@echo ""
	@echo "  ✓ MiskMatch is ready! Bismillah 🌙"
	@echo "  API: http://localhost:8000"
	@echo "  Docs: http://localhost:8000/docs"
	@echo ""
