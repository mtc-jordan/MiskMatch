"""
MiskMatch — FastAPI Application
Islamic Matrimony Platform
"Sealed with musk." — ختامه مسك — Quran 83:26
"""

from contextlib import asynccontextmanager

from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError

from app.core.config import settings
from app.core.database import engine, Base
from app.routers import auth, profiles, matches, games, messages, wali, compatibility, calls


# ─────────────────────────────────────────────
# Lifespan
# ─────────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Dev: auto-create tables. Prod: use Alembic."""
    if settings.is_development:
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
    yield
    await engine.dispose()


# ─────────────────────────────────────────────
# App instance
# ─────────────────────────────────────────────
app = FastAPI(
    title="MiskMatch API",
    description="""
## مسك ماتش — Islamic Matrimony Platform

> *\"ختامه مسك\"* — Its seal is musk. **Quran 83:26**

### Authentication
All protected endpoints require a Bearer JWT token.
Get yours from `/api/v1/auth/login`.

### Sprints Complete
- ✅ Auth (6 routes)
- ✅ Profiles (14 routes)
- ✅ Matches (10 routes)
- ✅ Chat + WebSocket (7 REST + 1 WS)
- ✅ Games Engine — 17 games (9 REST + 1 WS)
- ✅ Alembic Migrations + Seed data

**Next:** Wali Portal · Calls · Admin · Flutter App
    """,
    version=settings.APP_VERSION,
    docs_url="/docs" if not settings.is_production else None,
    redoc_url="/redoc" if not settings.is_production else None,
    lifespan=lifespan,
)


# ─────────────────────────────────────────────
# Middleware
# ─────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(GZipMiddleware, minimum_size=1000)


# ─────────────────────────────────────────────
# Exception handlers
# ─────────────────────────────────────────────
@app.exception_handler(RequestValidationError)
async def validation_handler(request: Request, exc: RequestValidationError):
    errors = []
    for error in exc.errors():
        field = " → ".join(str(loc) for loc in error["loc"] if loc != "body")
        errors.append({"field": field, "message": error["msg"]})
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={"detail": "Validation error", "errors": errors},
    )


@app.exception_handler(404)
async def not_found_handler(request: Request, exc):
    return JSONResponse(status_code=404, content={"detail": "Resource not found"})


@app.exception_handler(500)
async def internal_error_handler(request: Request, exc):
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error. Our team has been notified."},
    )


# ─────────────────────────────────────────────
# Routers — /api/v1
# ─────────────────────────────────────────────
PREFIX = settings.API_V1_PREFIX  # /api/v1

app.include_router(auth.router,     prefix=PREFIX)
app.include_router(profiles.router, prefix=PREFIX)
app.include_router(matches.router,  prefix=PREFIX)
app.include_router(games.router,    prefix=PREFIX)
app.include_router(messages.router, prefix=PREFIX)
app.include_router(wali.router,          prefix=PREFIX)
app.include_router(compatibility.router, prefix=PREFIX)
app.include_router(calls.router,         prefix=PREFIX)


# ─────────────────────────────────────────────
# Health check
# ─────────────────────────────────────────────
@app.get("/health", tags=["System"])
async def health():
    return {
        "status":      "healthy",
        "app":         settings.APP_NAME,
        "version":     settings.APP_VERSION,
        "environment": settings.ENVIRONMENT,
        "routes":      "46 REST + 2 WebSocket",
        "quran":       "ختامه مسك — Quran 83:26",
    }


@app.get("/", tags=["System"])
async def root():
    return {
        "app":     "MiskMatch API",
        "version": settings.APP_VERSION,
        "docs":    "/docs",
        "tagline": "Sealed with musk. — ختامه مسك",
    }
