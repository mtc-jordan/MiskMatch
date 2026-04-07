# MiskMatch — Backend API
## مسك ماتش — Islamic Matrimony Platform
### *"ختامه مسك"* — Sealed with musk. — Quran 83:26

---

## Tech Stack

| Layer | Technology |
|---|---|
| **API** | FastAPI 0.115 + Python 3.12 |
| **Database** | PostgreSQL 16 (Supabase in prod) |
| **Cache / Queue** | Redis 7 + Celery |
| **Auth** | JWT (python-jose) + bcrypt |
| **OTP** | Twilio SMS |
| **Storage** | AWS S3 + CloudFront (Bahrain region) |
| **Video** | Agora RTC |
| **AI** | OpenAI GPT-4o-mini + custom embeddings |
| **Payments** | Stripe + HyperPay (MENA) |
| **Biometric** | Onfido liveness + ID |
| **Monitoring** | Sentry + Prometheus |
| **Mobile** | Flutter (separate repo) |

---

## Quick Start

### 1. Clone and setup

```bash
git clone https://github.com/your-org/miskmatch-api
cd miskmatch-api
cp .env.example .env
# Fill in your .env values
```

### 2. Run with Docker (recommended)

```bash
docker compose up -d
# API:      http://localhost:8000
# Docs:     http://localhost:8000/docs
# PgAdmin:  http://localhost:5050
# Flower:   http://localhost:5555
```

### 3. Run locally (without Docker)

```bash
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt

# Database must be running
alembic upgrade head       # run migrations

uvicorn app.main:app --reload --port 8000
```

---

## Project Structure

```
miskmatch/
├── app/
│   ├── main.py              # FastAPI app, middleware, routers
│   ├── core/
│   │   ├── config.py        # Pydantic settings from .env
│   │   ├── database.py      # Async SQLAlchemy engine + session
│   │   └── security.py      # JWT + bcrypt utilities
│   ├── models/
│   │   └── models.py        # ALL database models (User, Profile,
│   │                        #   Family, Wali, Match, Game, Message,
│   │                        #   Call, Mosque, Notification, etc.)
│   ├── schemas/
│   │   ├── auth.py          # Pydantic request/response schemas
│   │   ├── profiles.py      # (next to build)
│   │   ├── matches.py       # (next to build)
│   │   └── games.py         # (next to build)
│   ├── routers/
│   │   ├── auth.py          # POST /auth/register, /login, etc.
│   │   ├── profiles.py      # GET/PUT /profiles (next)
│   │   ├── matches.py       # match system (next)
│   │   ├── games.py         # 17 games (next)
│   │   ├── messages.py      # supervised chat (next)
│   │   ├── wali.py          # guardian portal (next)
│   │   ├── calls.py         # Agora video (next)
│   │   └── admin.py         # admin dashboard (next)
│   ├── services/
│   │   ├── notifications.py # SMS, push, email
│   │   ├── ai.py            # compatibility engine (next)
│   │   ├── storage.py       # S3 upload (next)
│   │   └── payments.py      # Stripe (next)
│   ├── middleware/
│   │   └── rate_limit.py    # rate limiting (next)
│   └── utils/
│       └── arabic.py        # RTL/Arabic text helpers (next)
├── tests/
│   ├── test_auth.py
│   └── test_matches.py
├── alembic/                 # Database migrations
├── scripts/
│   └── seed.py              # Dev data seeding
├── docker-compose.yml
├── Dockerfile
├── requirements.txt
└── .env.example
```

---

## API Endpoints (v1)

### Auth `/api/v1/auth`
| Method | Path | Description |
|---|---|---|
| POST | `/register` | Register new user |
| POST | `/verify-otp` | Verify phone OTP |
| POST | `/login` | Login, get JWT tokens |
| POST | `/refresh` | Refresh access token |
| POST | `/resend-otp` | Resend OTP |
| POST | `/logout` | Logout, clear FCM token |

### Profiles `/api/v1/profiles` *(next sprint)*
| Method | Path | Description |
|---|---|---|
| GET | `/me` | Get my profile |
| PUT | `/me` | Update my profile |
| GET | `/{user_id}` | Get user profile |
| POST | `/me/photo` | Upload profile photo |
| POST | `/me/voice` | Upload voice intro |
| POST | `/me/family` | Update family profile |

### Matches `/api/v1/matches` *(next sprint)*
| Method | Path | Description |
|---|---|---|
| GET | `/discover` | Discovery feed |
| POST | `/interest` | Express interest |
| POST | `/{id}/respond` | Accept/decline |
| GET | `/` | My matches list |
| GET | `/{id}` | Single match detail |

### Games `/api/v1/games` *(next sprint)*
| Method | Path | Description |
|---|---|---|
| POST | `/` | Start a game |
| GET | `/match/{match_id}` | Games for a match |
| POST | `/{id}/answer` | Submit answer |
| GET | `/{id}/results` | Game results |

---

## Best Practices Applied

### Security
- ✅ bcrypt password hashing (12 rounds)
- ✅ JWT with short-lived access + long-lived refresh
- ✅ Phone OTP verification before account activation
- ✅ Soft delete — user data never hard-deleted
- ✅ Input validation via Pydantic v2
- ✅ Non-root Docker user
- ✅ CORS configured per environment
- ✅ Rate limiting middleware (configured in middleware/)

### Database
- ✅ Async SQLAlchemy — no blocking I/O
- ✅ Connection pooling (20 pool, 40 overflow)
- ✅ Pool pre-ping — dead connection detection
- ✅ Proper indexing on all foreign keys and query fields
- ✅ Naming conventions for Alembic migrations
- ✅ Check constraints for business rules
- ✅ Soft delete pattern (deleted_at timestamp)

### Code Quality
- ✅ Type hints everywhere (Python 3.12 style)
- ✅ Pydantic v2 for all schemas
- ✅ Dependency injection (get_db, get_current_user)
- ✅ Background tasks for non-blocking operations (SMS)
- ✅ Proper exception handling with user-friendly messages
- ✅ Environment-specific behavior (dev vs production)
- ✅ Comprehensive docstrings

### Islamic Compliance
- ✅ Niyyah (intention) captured at registration
- ✅ Wali (guardian) system built into data model
- ✅ Chaperoned calls modeled as first-class feature
- ✅ Moderation system for all messages
- ✅ Mosque verification trust system
- ✅ Soft blocking — no hard data deletion

---

## Running Tests

```bash
pytest tests/ -v --asyncio-mode=auto
```

---

## Alembic Migrations

```bash
# Create new migration
alembic revision --autogenerate -m "add_profile_table"

# Apply migrations
alembic upgrade head

# Rollback one step
alembic downgrade -1
```

---

*MiskMatch API — Built with barakah 🌹*
*"ختامه مسك" — Quran 83:26*
