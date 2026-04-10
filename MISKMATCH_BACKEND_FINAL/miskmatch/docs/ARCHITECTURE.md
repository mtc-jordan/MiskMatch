# MiskMatch — Architecture Guide

## System Architecture

```
┌────────────────────────────────────────────────────────────┐
│                     Flutter Mobile App                      │
│  Auth → Profile → Discovery → Match → Chat → Games → Calls │
└─────────────────────────┬──────────────────────────────────┘
                          │ HTTPS + WebSocket
                          ▼
┌────────────────────────────────────────────────────────────┐
│                    FastAPI Application                       │
│                                                             │
│  ┌─────────┐ ┌──────────┐ ┌────────┐ ┌──────┐ ┌────────┐ │
│  │  Auth   │ │ Profiles │ │ Matches│ │ Chat │ │ Games  │ │
│  │ Router  │ │  Router  │ │ Router │ │Router│ │ Router │ │
│  └────┬────┘ └────┬─────┘ └───┬────┘ └──┬───┘ └───┬────┘ │
│       │           │           │          │         │       │
│  ┌────▼───────────▼───────────▼──────────▼─────────▼────┐ │
│  │                   Service Layer                       │ │
│  │  matches · profiles · messages · games · calls        │ │
│  │  compatibility · embeddings · moderation · wali       │ │
│  │  notifications · storage                              │ │
│  └────┬───────────┬───────────┬──────────┬──────────────┘ │
│       │           │           │          │                 │
│  ┌────▼────┐ ┌────▼────┐ ┌───▼───┐ ┌───▼────┐           │
│  │Postgres │ │  Redis  │ │Celery │ │External│           │
│  │  (async)│ │(cache/  │ │Workers│ │Services│           │
│  │         │ │ queue)  │ │       │ │        │           │
│  └─────────┘ └─────────┘ └───────┘ └────────┘           │
└────────────────────────────────────────────────────────────┘

External Services:
  Twilio (SMS)  ·  OpenAI (AI)  ·  AWS S3 (storage)  ·  Agora (video)
  Stripe (payments)  ·  Onfido (biometric)  ·  Firebase (push)  ·  Sentry (errors)
```

---

## Request Flow

```
Client Request
    │
    ▼
CORS Middleware          → Origin validation
    │
    ▼
Rate Limit Middleware    → Redis sorted set check
    │
    ▼
Router                   → Path matching, dependency injection
    │
    ▼
get_current_user         → JWT decode + blacklist check + user load
    │
    ▼
Service Layer            → Business logic, validation, DB operations
    │
    ▼
Database Session         → Auto-commit on success, rollback on error
    │
    ▼
Response                 → Pydantic schema serialization
```

---

## Database Design

### Core Entities

```
User (1) ──── (1) Profile
  │                  │
  │                  ├── Family
  │                  ├── SearchPreferences (embedded in Profile)
  │                  └── compatibility_embedding (vector)
  │
  ├──── WaliRelationship ────── Wali User
  │
  ├──── Match (sender/receiver)
  │       ├── Message (many)
  │       ├── Game (many)
  │       └── Call (many)
  │
  ├──── Notification (many)
  ├──── Subscription (many)
  └──── Report (reporter/reported)

Mosque (standalone, for verification)
```

### Key Design Decisions

**Soft Delete**: Users are never hard-deleted. `deleted_at` timestamp preserves data integrity while hiding the account. All queries filter `WHERE deleted_at IS NULL`.

**Enum Types**: PostgreSQL native enums for type safety:
- `UserRole` (USER, ADMIN, MODERATOR)
- `UserStatus` (PENDING, ACTIVE, BANNED, DELETED)
- `Gender` (MALE, FEMALE)
- `MatchStatus` (PENDING, MUTUAL, WALI_REVIEW, ACTIVE, CLOSED, NIKAH)
- `MessageStatus` (SENT, DELIVERED, READ)
- `CallStatus` (SCHEDULED, RINGING, ACTIVE, ENDED, MISSED, CANCELLED)

**Nullable Booleans**: `sender_wali_approved` / `receiver_wali_approved` use three-state logic:
- `NULL` = not yet decided
- `True` = approved
- `False` = declined

---

## Match Lifecycle

```
                    ┌──────────┐
                    │ DISCOVER │  AI-ranked feed
                    └────┬─────┘
                         │ express_interest()
                    ┌────▼─────┐
                    │ PENDING  │  Waiting for receiver
                    └────┬─────┘
                    ┌────┴─────┐
               accept()    decline()
                    │          │
              ┌─────▼────┐ ┌──▼────┐
              │  MUTUAL   │ │CLOSED │
              └─────┬─────┘ └───────┘
                    │
         ┌──────────┴──────────┐
    has_wali?              no_wali
         │                     │
   ┌─────▼──────┐             │
   │ WALI_REVIEW│             │
   └─────┬──────┘             │
    both approve              │
         │                    │
    ┌────▼────────────────────▼──┐
    │          ACTIVE             │  Chat + Games + Calls unlocked
    └────┬───────────────┬───────┘
         │               │
    ┌────▼────┐    ┌─────▼────┐
    │  NIKAH  │    │  CLOSED  │
    │(success)│    │(graceful)│
    └─────────┘    └──────────┘
```

---

## AI Compatibility Engine

### Two-Layer Scoring

```
Final Score = (Rule Score × 0.6) + (AI Score × 0.4)
```

**Layer 1 — Rule-Based (60%)**

Structured field comparison with weighted categories:

| Category | Weight | Fields Compared |
|---|---|---|
| Islamic Practice | 25% | Prayer frequency, madhab, Quran level |
| Life Goals | 20% | Children, Hajj, hijra, Islamic finance |
| Lifestyle | 20% | Location, age range, education |
| Values | 20% | Sifr personality scores (5 dimensions) |
| Preferences | 15% | Explicit dealbreakers |

Each rule returns a score and explanation text (e.g., "Both pray all five daily prayers").

**Layer 2 — AI Embedding (40%)**

1. Convert structured profile → natural language text (Islamic practice, goals, personality, bio)
2. Embed with OpenAI `text-embedding-3-small` (1536 dimensions)
3. Store vector in `Profile.compatibility_embedding`
4. At query time: cosine similarity → scaled to 0-100

Cost: ~$0.000015 per profile embed. 100,000 users = $1.50 total.

### Discovery Ranking

```python
candidates = (
    opposite_gender
    & age_in_range
    & location_preference
    & not_already_matched
    & not_blocked
)
ranked = sort_by(compatibility_score, descending)
return paginate(ranked, limit=20)
```

---

## Supervised Communication

### Message Flow

```
Sender types message
    │
    ▼
WebSocket → Server
    │
    ▼
AI Moderation (GPT-4o-mini)
    │
    ├── PASS → Store + deliver to receiver
    │
    └── BLOCK → Store (flagged) + notify sender
                  + alert wali if configured
```

### Wali Oversight

Guardians (wali) can:
- View all conversations of their wards
- See moderation flags and blocked messages
- Approve or decline matches
- Approve or decline chaperoned calls
- Access full dashboard with activity summary

---

## WebSocket Protocol

### Chat WebSocket (`/api/v1/messages/ws/{match_id}?token=<jwt>`)

**Client → Server:**
```json
{"type": "message", "content": "Assalamu alaikum", "temp_id": "uuid"}
{"type": "typing", "is_typing": true}
{"type": "mark_read", "message_ids": ["uuid1", "uuid2"]}
```

**Server → Client:**
```json
{"type": "message", "data": {"id": "uuid", "content": "...", "sender_id": "..."}}
{"type": "typing", "data": {"user_id": "...", "is_typing": true}}
{"type": "read_receipt", "data": {"message_ids": [...], "reader_id": "..."}}
{"type": "moderation", "data": {"message": "Content blocked — Islamic guidelines"}}
{"type": "presence", "data": {"user_id": "...", "online": true}}
```

### Game WebSocket (`/api/v1/games/ws/{match_id}?token=<jwt>`)

**Client → Server:**
```json
{"type": "answer", "game_type": "halal_haram", "data": {"answer": "halal"}}
```

**Server → Client:**
```json
{"type": "game_update", "data": {"game_type": "...", "state": {...}}}
{"type": "game_complete", "data": {"game_type": "...", "results": {...}}}
```

---

## Security Model

### Authentication

```
Registration → bcrypt hash (12 rounds) → stored
Login → verify hash → JWT access (60 min) + refresh (30 days)
Each token has unique JTI (JWT ID)
Logout → JTI added to Redis blacklist (TTL = token expiry)
```

### Authorization Layers

1. **JWT validation** — every protected endpoint
2. **User status check** — banned users rejected (403)
3. **Gender isolation** — opposite-gender profiles only (returns 404, not 403)
4. **Match participation** — only match members can access chat/calls
5. **Wali verification** — guardian endpoints verify actual guardianship
6. **Rate limiting** — per-IP sliding window on auth endpoints

### Data Privacy

- Profile photos served via CloudFront (signed URLs possible)
- Voice/Quran recordings stored in separate S3 bucket
- Wali views exclude sensitive media by default
- Soft delete preserves data but hides from all queries
- No PII in logs (phone numbers partially masked)

---

## Background Tasks

### Celery Configuration

```python
broker:     Redis (same instance as cache)
backend:    Redis
serializer: JSON
timezone:   UTC
```

### Task List

| Task | Trigger | Retry | Description |
|---|---|---|---|
| `embed_profile_task` | Profile create/update | 3x, 60s delay | Generate AI compatibility vector |
| `reembed_stale_profiles_task` | Daily cron | 2x | Batch embed profiles missing vectors |
| `reembed_all_profiles_task` | Admin trigger | 1x | Full platform re-embed (reports progress) |

All tasks create their own database engine and dispose it in a `finally` block to prevent connection leaks.

---

## Caching Strategy

### Cache-Aside Pattern

```
GET request
    │
    ├── Cache HIT  → return cached response
    │
    └── Cache MISS → query DB → store in cache (TTL) → return
```

### Cache Keys

| Pattern | TTL | Invalidation |
|---|---|---|
| `profile:{user_id}` | 300s | Profile update |
| `discovery:*` | 300s | Any profile create/update |

### Rate Limiting

Redis sorted sets with sliding window:

| Endpoint | Limit |
|---|---|
| `/auth/register` | 5 per 60s per IP |
| `/auth/login` | 10 per 60s per IP |
| `/auth/resend-otp` | 3 per 60s per IP |

---

## Error Handling

### HTTP Status Codes

| Code | Meaning |
|---|---|
| 200 | Success |
| 201 | Created (new resource) |
| 401 | Invalid/expired/blacklisted token |
| 403 | Banned account or insufficient permissions |
| 404 | Resource not found (also used for gender isolation) |
| 422 | Validation error (Pydantic) |
| 429 | Rate limited |
| 500 | Internal server error (logged to Sentry) |

### Error Response Format

```json
{
  "detail": "Human-readable error message"
}
```

Validation errors include field-level detail:

```json
{
  "detail": [
    {
      "loc": ["body", "phone"],
      "msg": "Invalid phone number format. Use +962XXXXXXXXX",
      "type": "value_error"
    }
  ]
}
```
