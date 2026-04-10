# MiskMatch — Backend API
## Islamic Matrimony Platform
### *"Sealed with musk."* — Quran 83:26

---

## Tech Stack

| Layer | Technology |
|---|---|
| **API** | FastAPI 0.115 + Python 3.12 |
| **Database** | PostgreSQL 16 (async via asyncpg) |
| **Cache / Queue** | Redis 7 + Celery |
| **Auth** | JWT (python-jose) + bcrypt |
| **OTP** | Twilio SMS |
| **Storage** | AWS S3 + CloudFront (Bahrain me-south-1) |
| **Video Calls** | Agora RTC (chaperoned) |
| **AI** | OpenAI GPT-4o-mini (moderation) + text-embedding-3-small (compatibility) |
| **Payments** | Stripe + HyperPay (MENA) |
| **Biometric** | Onfido liveness + ID verification |
| **Monitoring** | Sentry + Prometheus |
| **Mobile** | Flutter (separate directory) |

---

## Quick Start

### 1. Clone and configure

```bash
git clone <repo-url>
cd miskmatch
cp .env.example .env
# Edit .env with your values (see Environment Variables below)
```

### 2. Run with Docker (recommended)

```bash
docker compose up -d
```

| Service | URL |
|---|---|
| API | http://localhost:8000 |
| Swagger Docs | http://localhost:8000/docs |
| ReDoc | http://localhost:8000/redoc |
| PgAdmin | http://localhost:5050 |
| Flower (Celery) | http://localhost:5555 |

### 3. Run locally (without Docker)

```bash
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt

# Start PostgreSQL and Redis first, then:
alembic upgrade head                              # run migrations
python scripts/seed.py                            # seed test data
uvicorn app.main:app --reload --port 8000         # start API
```

### 4. Seed test data

```bash
python scripts/seed.py
```

Test accounts after seeding:
| User | Phone | Password |
|---|---|---|
| Yusuf (male) | +962791000001 | Test1234! |
| Fatima (female) | +962791000002 | Test1234! |

---

## Project Structure

```
miskmatch/
├── app/
│   ├── main.py                  # FastAPI app, middleware, lifespan
│   ├── core/
│   │   ├── config.py            # Pydantic settings from .env
│   │   ├── database.py          # Async SQLAlchemy engine + session
│   │   ├── redis.py             # Redis client, rate limiting, caching
│   │   ├── security.py          # JWT + bcrypt + OTP utilities
│   │   ├── websocket.py         # WebSocket connection manager
│   │   └── celery.py            # Celery app configuration
│   ├── models/
│   │   └── models.py            # All SQLAlchemy models (User, Profile,
│   │                            #   Family, WaliRelationship, Match,
│   │                            #   Game, Message, Call, Notification,
│   │                            #   Report, Subscription, Mosque)
│   ├── schemas/
│   │   ├── auth.py              # Auth request/response schemas
│   │   ├── profiles.py          # Profile CRUD schemas
│   │   ├── matches.py           # Match & discovery schemas
│   │   ├── games.py             # Game schemas
│   │   └── wali.py              # Wali/guardian schemas
│   ├── routers/
│   │   ├── auth.py              # Authentication & account
│   │   ├── profiles.py          # Profile management & media
│   │   ├── matches.py           # Discovery, interest, matching
│   │   ├── games.py             # 17 Islamic compatibility games
│   │   ├── messages.py          # Supervised chat + WebSocket
│   │   ├── calls.py             # Agora chaperoned video calls
│   │   ├── wali.py              # Guardian portal
│   │   ├── compatibility.py     # AI compatibility engine
│   │   └── webhooks.py          # Stripe & Onfido webhooks
│   ├── services/
│   │   ├── matches.py           # Match logic, discovery ranking
│   │   ├── profiles.py          # Profile CRUD, trust score
│   │   ├── messages.py          # Message storage, delivery
│   │   ├── games.py             # Game state machine (17 games)
│   │   ├── calls.py             # Call scheduling, Agora tokens
│   │   ├── wali.py              # Guardian management
│   │   ├── compatibility.py     # Rule-based + AI scoring
│   │   ├── embeddings.py        # OpenAI profile vectorisation
│   │   ├── moderation.py        # AI content moderation
│   │   ├── notifications.py     # SMS, push, email
│   │   └── storage.py           # S3 upload/download
│   └── workers/
│       └── tasks.py             # Celery background tasks
├── tests/                       # Pytest async test suite
├── alembic/                     # Database migrations
├── scripts/
│   └── seed.py                  # Development data seeding
├── docker-compose.yml           # Full dev environment
├── Dockerfile                   # Multi-stage production build
├── requirements.txt
└── .env.example
```

---

## API Endpoints

All endpoints are prefixed with `/api/v1`. Interactive docs at `/docs` (Swagger) or `/redoc`.

### Authentication `/api/v1/auth`

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/register` | - | Register new user with phone + password |
| POST | `/verify-otp` | - | Verify phone via OTP code |
| POST | `/login` | - | Login, receive JWT tokens |
| POST | `/refresh` | - | Refresh expired access token |
| POST | `/resend-otp` | - | Resend OTP to phone |
| POST | `/logout` | JWT | Logout, blacklist token, clear FCM |
| POST | `/device-token` | JWT | Register FCM push token |
| DELETE | `/account` | JWT | Soft-delete user account |

### Profiles `/api/v1/profiles`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/me` | JWT | Get my full profile |
| POST | `/me` | JWT | Create profile (onboarding) |
| PUT | `/me` | JWT | Update profile fields |
| GET | `/me/completion` | JWT | Profile completion percentage |
| POST | `/me/photo` | JWT | Upload main profile photo |
| POST | `/me/gallery` | JWT | Add photo to gallery |
| DELETE | `/me/gallery/{idx}` | JWT | Remove gallery photo |
| POST | `/me/voice` | JWT | Upload voice introduction |
| POST | `/me/quran` | JWT | Upload Quran recitation |
| GET | `/me/family` | JWT | Get family profile |
| PUT | `/me/family` | JWT | Create/update family profile |
| POST | `/me/sifr` | JWT | Submit Sifr personality assessment |
| PUT | `/me/preferences` | JWT | Update search preferences |
| GET | `/{user_id}` | JWT | View another user's public profile |

### Matches `/api/v1/matches`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/discover` | JWT | AI-ranked discovery feed |
| POST | `/interest` | JWT | Express interest in a profile |
| GET | `/` | JWT | List my matches |
| GET | `/wali/pending` | JWT | Wali: matches pending approval |
| GET | `/{id}` | JWT | Single match detail |
| POST | `/{id}/respond` | JWT | Accept or decline interest |
| POST | `/{id}/wali-approve` | JWT | Wali approves/declines match |
| POST | `/{id}/close` | JWT | Close a match gracefully |
| POST | `/{id}/nikah` | JWT | Record nikah outcome |
| GET | `/{id}/compatibility` | JWT | Detailed compatibility breakdown |

### Games `/api/v1/games`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/{match_id}` | JWT | Game catalogue for a match |
| POST | `/{match_id}/{type}/start` | JWT | Start a new game |
| GET | `/{match_id}/{type}` | JWT | Get game state (resume) |
| POST | `/{match_id}/{type}/turn` | JWT | Submit async game turn |
| POST | `/{match_id}/{type}/realtime` | JWT | Submit real-time answer |
| POST | `/{match_id}/time-capsule/seal` | JWT | Seal time capsule |
| POST | `/{match_id}/time-capsule/open` | JWT | Open time capsule |
| GET | `/{match_id}/memory` | JWT | Match memory timeline |
| WS | `/ws/{match_id}` | Token | Real-time game WebSocket |

### Messages `/api/v1/messages`

| Method | Path | Auth | Description |
|---|---|---|---|
| WS | `/ws/{match_id}` | Token | Real-time chat WebSocket |
| GET | `/{match_id}` | JWT | Paginated message history |
| POST | `/{match_id}` | JWT | Send message (REST fallback) |
| PUT | `/{match_id}/read` | JWT | Mark messages as read |
| POST | `/{match_id}/report` | JWT | Report inappropriate message |
| GET | `/wali/conversations` | JWT | Wali: conversation summaries |
| GET | `/wali/{match_id}` | JWT | Wali: full conversation view |

### Chaperoned Calls `/api/v1/calls`

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/initiate` | JWT | Start or schedule a call |
| POST | `/{id}/join` | JWT | Join call, get Agora token |
| POST | `/{id}/end` | JWT | End active call |
| GET | `/{id}` | JWT | Call details |
| GET | `/match/{match_id}/history` | JWT | Call history for a match |
| GET | `/active` | JWT | My currently active call |
| POST | `/{id}/wali-approve` | JWT | Wali approves/declines call |

### Wali Portal `/api/v1/wali`

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/register` | JWT | Register a guardian |
| POST | `/invite` | JWT | Send SMS invitation to wali |
| POST | `/resend-invite` | JWT | Resend invitation |
| POST | `/accept` | JWT | Wali accepts guardianship |
| GET | `/status` | JWT | My wali setup status |
| PUT | `/permissions` | JWT | Update wali permissions |
| DELETE | `/` | JWT | Remove wali |
| GET | `/dashboard` | JWT | Wali: full portal dashboard |
| GET | `/wards` | JWT | Wali: list all wards |
| GET | `/pending` | JWT | Wali: all pending decisions |
| GET | `/match/{match_id}` | JWT | Wali: match summary |
| POST | `/match/{match_id}/decide` | JWT | Wali: approve/decline match |

### AI Compatibility `/api/v1/compatibility`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/match/{match_id}` | JWT | Full compatibility report |
| GET | `/preview/{user_id}` | JWT | Preview before expressing interest |
| POST | `/embed` | JWT | Trigger re-embedding of my profile |
| GET | `/embed/status` | JWT | Check my embedding status |
| POST | `/admin/reembed-all` | Admin | Re-embed all profiles |
| GET | `/admin/reembed-progress/{id}` | Admin | Check batch job progress |
| GET | `/admin/stats` | Admin | Embedding coverage statistics |

### Webhooks `/api/v1/webhooks`

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/stripe` | Signature | Stripe payment events |
| POST | `/onfido` | Signature | Onfido verification events |

---

## Architecture

### Authentication Flow

```
Register (phone + password)
    → OTP sent via Twilio SMS
    → Verify OTP → account ACTIVE
    → Login → JWT access (60 min) + refresh (30 days)
    → All endpoints require Bearer token
    → Token blacklisting on logout via Redis
```

### Match Lifecycle

```
DISCOVER → PENDING → MUTUAL → WALI_REVIEW → ACTIVE → [NIKAH | CLOSED]
                 ↓                                         ↑
              DECLINED                              close/expire
```

1. **Discover**: AI-ranked profiles based on preferences + embedding similarity
2. **Interest**: Sender expresses interest with a message
3. **Mutual**: Receiver accepts, both users matched
4. **Wali Review**: Both guardians must approve (if configured)
5. **Active**: Chat, games, and chaperoned calls unlocked
6. **Outcome**: Nikah (success) or graceful closure

### AI Compatibility Engine

Two-layer scoring:

1. **Rule-based (60%)**: Structured field comparison (prayer, madhab, children, location, age)
2. **AI embedding (40%)**: OpenAI text-embedding-3-small cosine similarity on full profile text

Profile text captures Islamic practice, life goals, personality (Sifr 5-dimension scores), and free-text bio.

### Supervised Communication

- All messages pass through AI moderation (OpenAI GPT-4o-mini)
- Wali (guardian) can view all conversations
- Chaperoned video calls require wali approval
- Content flagging and reporting system

### Background Tasks (Celery)

| Task | Trigger | Description |
|---|---|---|
| `embed_profile_task` | Profile create/update | Generate compatibility vector |
| `reembed_stale_profiles_task` | Cron (daily) | Re-embed profiles missing vectors |
| `reembed_all_profiles_task` | Admin manual | Batch re-embed entire platform |

---

## Environment Variables

Copy `.env.example` to `.env`. Key variables:

| Variable | Required | Description |
|---|---|---|
| `SECRET_KEY` | Yes | JWT signing key (min 32 chars) |
| `DATABASE_URL` | Yes | PostgreSQL async connection string |
| `REDIS_URL` | Yes | Redis connection string |
| `TWILIO_*` | Prod | SMS OTP delivery |
| `OPENAI_API_KEY` | Prod | AI moderation + embeddings |
| `AWS_*` / `S3_*` | Prod | Media storage |
| `AGORA_*` | Prod | Video call tokens |
| `STRIPE_*` | Prod | Payment processing |
| `ONFIDO_*` | Prod | Biometric verification |
| `SENTRY_DSN` | Prod | Error tracking |
| `FIREBASE_CREDENTIALS_PATH` | Prod | Push notifications |

---

## Database Migrations

```bash
# Apply all pending migrations
alembic upgrade head

# Create new auto-generated migration
alembic revision --autogenerate -m "describe_change"

# Rollback one step
alembic downgrade -1

# View current revision
alembic current
```

---

## Testing

```bash
# Run all tests
pytest tests/ -v --asyncio-mode=auto

# Run specific module
pytest tests/test_auth.py -v

# Run with coverage
pytest tests/ --cov=app --cov-report=term-missing
```

Test suite uses async SQLite in-memory database and mocked external services (Twilio, OpenAI, S3, Stripe).

---

## Docker

### Development

```bash
docker compose up -d          # Start all services
docker compose logs -f api    # Follow API logs
docker compose down           # Stop all
```

### Production build

```bash
docker build -t miskmatch-api .
docker run -p 8000:8000 --env-file .env miskmatch-api
```

The Dockerfile uses multi-stage build with non-root user. Production runs 4 uvicorn workers with proxy headers enabled.

---

## Performance

- **N+1 queries eliminated**: Batch loading with `IN` clauses for matches, messages, profiles
- **Redis caching**: Profile and discovery results cached with TTL-based invalidation
- **Connection pooling**: asyncpg pool (10 + 20 overflow), 1800s recycle, statement cache
- **Composite indexes**: Optimized for common query patterns (sender+status, match+created_at)
- **Background tasks**: Embedding generation and batch operations run async via Celery

---

## Security

- bcrypt password hashing (12 rounds)
- JWT with JTI-based token revocation via Redis blacklist
- Phone OTP verification required before activation
- AI content moderation on all messages
- Wali (guardian) oversight on matches and calls
- Rate limiting on auth endpoints (Redis sorted sets)
- Input validation via Pydantic v2 strict schemas
- Non-root Docker container
- CORS configured per environment
- Gender-isolated profile access (opposite gender only)

---

*MiskMatch API — Built with barakah*
*"Sealed with musk." — Quran 83:26*
