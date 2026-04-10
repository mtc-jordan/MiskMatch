"""
MiskMatch — FastAPI Application
Islamic Matrimony Platform
"Sealed with musk." — ختامه مسك — Quran 83:26
"""

import logging
import uuid as _uuid
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError

from app.core.config import settings
from app.core.database import engine, Base
from app.routers import auth, profiles, matches, games, messages, wali, compatibility, calls, webhooks

logger = logging.getLogger("miskmatch")


# ─────────────────────────────────────────────
# Logging configuration
# ─────────────────────────────────────────────
def _configure_logging() -> None:
    level = logging.DEBUG if settings.DEBUG else logging.INFO

    if settings.is_production:
        # Structured JSON logging for log aggregation (CloudWatch, Datadog, etc.)
        import json

        class JSONFormatter(logging.Formatter):
            def format(self, record: logging.LogRecord) -> str:
                log_entry = {
                    "timestamp": self.formatTime(record, self.datefmt),
                    "level": record.levelname,
                    "logger": record.name,
                    "message": record.getMessage(),
                }
                if record.exc_info and record.exc_info[1]:
                    log_entry["exception"] = self.formatException(record.exc_info)
                if hasattr(record, "request_id"):
                    log_entry["request_id"] = record.request_id
                return json.dumps(log_entry)

        handler = logging.StreamHandler()
        handler.setFormatter(JSONFormatter())
        logging.root.handlers = [handler]
        logging.root.setLevel(level)
    else:
        fmt = "%(asctime)s | %(levelname)-7s | %(name)s | %(message)s"
        logging.basicConfig(level=level, format=fmt)

    # Quiet noisy libraries
    logging.getLogger("sqlalchemy.engine").setLevel(logging.WARNING)
    logging.getLogger("uvicorn.access").setLevel(logging.INFO)
    logging.getLogger("httpcore").setLevel(logging.WARNING)

_configure_logging()


# ─────────────────────────────────────────────
# Lifespan
# ─────────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Dev: auto-create tables. Prod: use Alembic."""
    if settings.is_development:
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
    elif settings.is_production:
        logger.info("Production mode — tables must be managed via Alembic migrations")
    yield
    from app.core.redis import close_redis
    await close_redis()
    await engine.dispose()


# ─────────────────────────────────────────────
# Production environment validation
# ─────────────────────────────────────────────
def _validate_production_config() -> None:
    """Fail fast if critical config is missing in production."""
    if not settings.is_production:
        return

    missing = []
    if not settings.TWILIO_ACCOUNT_SID:
        missing.append("TWILIO_ACCOUNT_SID")
    if not settings.OPENAI_API_KEY:
        missing.append("OPENAI_API_KEY (message moderation)")
    if not settings.SENTRY_DSN:
        missing.append("SENTRY_DSN (error tracking)")
    if not settings.STRIPE_SECRET_KEY:
        missing.append("STRIPE_SECRET_KEY")
    if settings.ADMIN_PASSWORD in ("", "change-this-immediately"):
        missing.append("ADMIN_PASSWORD (must be changed)")
    if "localhost" in settings.DATABASE_URL:
        missing.append("DATABASE_URL (still pointing to localhost)")

    if missing:
        msg = "Production config errors — missing or default values:\n  • " + "\n  • ".join(missing)
        logger.error(msg)
        raise RuntimeError(msg)

_validate_production_config()


# ─────────────────────────────────────────────
# Sentry integration (production)
# ─────────────────────────────────────────────
if settings.SENTRY_DSN:
    try:
        import sentry_sdk
        from sentry_sdk.integrations.fastapi import FastApiIntegration
        from sentry_sdk.integrations.sqlalchemy import SqlalchemyIntegration

        sentry_sdk.init(
            dsn=settings.SENTRY_DSN,
            environment=settings.ENVIRONMENT,
            traces_sample_rate=0.1 if settings.is_production else 1.0,
            integrations=[FastApiIntegration(), SqlalchemyIntegration()],
        )
        logger.info("Sentry initialized")
    except Exception as e:
        logger.warning(f"Sentry init failed: {e}")


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
    """,
    version=settings.APP_VERSION,
    docs_url="/docs" if not settings.is_production else None,
    redoc_url="/redoc" if not settings.is_production else None,
    lifespan=lifespan,
)


# ─────────────────────────────────────────────
# Middleware
# ─────────────────────────────────────────────
_cors_origins = settings.ALLOWED_ORIGINS
if settings.is_production:
    _cors_origins = [o.strip() for o in settings.PRODUCTION_ORIGINS.split(",") if o.strip()]

app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "Accept", "Accept-Language", "X-Request-ID"],
)
app.add_middleware(GZipMiddleware, minimum_size=1000)


# ─────────────────────────────────────────────
# Prometheus metrics
# ─────────────────────────────────────────────
try:
    from prometheus_fastapi_instrumentator import Instrumentator

    _instrumentator = Instrumentator(
        should_group_status_codes=True,
        should_ignore_untemplated=True,
        excluded_handlers=["/health", "/metrics", "/"],
    )
    _instrumentator.instrument(app)
    _instrumentator.expose(app, endpoint="/metrics", tags=["System"])
    logger.info("Prometheus metrics enabled at /metrics")
except ImportError:
    logger.debug("prometheus-fastapi-instrumentator not installed — metrics disabled")


# ─────────────────────────────────────────────
# Request ID middleware
# ─────────────────────────────────────────────
@app.middleware("http")
async def request_id_middleware(request: Request, call_next):
    """Attach a unique request ID for tracing. Reuses client-provided X-Request-ID if present."""
    request_id = request.headers.get("X-Request-ID") or str(_uuid.uuid4())
    request.state.request_id = request_id
    response = await call_next(request)
    response.headers["X-Request-ID"] = request_id
    return response


# ─────────────────────────────────────────────
# Security headers middleware
# ─────────────────────────────────────────────
@app.middleware("http")
async def security_headers_middleware(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
    if settings.is_production:
        response.headers["Strict-Transport-Security"] = (
            "max-age=63072000; includeSubDomains; preload"
        )
        response.headers["Content-Security-Policy"] = (
            "default-src 'none'; frame-ancestors 'none'"
        )
    return response


# ─────────────────────────────────────────────
# Request logging middleware
# ─────────────────────────────────────────────
@app.middleware("http")
async def request_logging_middleware(request: Request, call_next):
    import time
    start = time.perf_counter()
    response = await call_next(request)
    elapsed = (time.perf_counter() - start) * 1000
    request_id = getattr(request.state, "request_id", "-")
    if elapsed > 1000:  # log slow requests (>1s)
        logger.warning(
            f"SLOW {request.method} {request.url.path} → {response.status_code} ({elapsed:.0f}ms) [{request_id}]"
        )
    return response


# ─────────────────────────────────────────────
# Rate limiting middleware (Redis-backed)
# ─────────────────────────────────────────────
_RATE_LIMIT_ROUTES = {
    "/api/v1/auth/register":   (5,  60),   # 5 per minute
    "/api/v1/auth/login":      (10, 60),   # 10 per minute
    "/api/v1/auth/verify-otp": (10, 60),   # 10 per minute
    "/api/v1/auth/resend-otp": (3,  60),   # 3 per minute
}

@app.middleware("http")
async def rate_limit_middleware(request: Request, call_next):
    path = request.url.path
    if path in _RATE_LIMIT_ROUTES:
        max_requests, window = _RATE_LIMIT_ROUTES[path]
        client_ip = request.client.host if request.client else "unknown"
        key = f"{client_ip}:{path}"

        try:
            from app.core.redis import check_rate_limit
            allowed = await check_rate_limit(key, max_requests, window)
        except Exception as e:
            # If Redis is down, allow the request (fail-open) but log it
            logger.warning(f"Rate limit check failed (fail-open): {e}")
            allowed = True

        if not allowed:
            return JSONResponse(
                status_code=429,
                content={"detail": "Too many requests. Please try again later."},
            )

    return await call_next(request)


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
    logger.error(f"500 error on {request.method} {request.url}: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error. Our team has been notified."},
    )


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    logger.error(
        f"Unhandled {type(exc).__name__} on {request.method} {request.url}: {exc}",
        exc_info=True,
    )
    detail = "Internal server error. Our team has been notified."
    if settings.is_development:
        detail = f"{type(exc).__name__}: {exc}"
    return JSONResponse(
        status_code=500,
        content={"detail": detail},
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
app.include_router(webhooks.router,      prefix=PREFIX)


# ─────────────────────────────────────────────
# Health check
# ─────────────────────────────────────────────
@app.get("/health", tags=["System"])
async def health():
    checks = {"database": "ok", "redis": "ok"}

    # Database check
    try:
        from sqlalchemy import text
        from app.core.database import AsyncSessionLocal

        async with AsyncSessionLocal() as db:
            await db.execute(text("SELECT 1"))
    except Exception as e:
        checks["database"] = f"error: {e}"

    # Redis check
    try:
        from app.core.redis import get_redis

        r = await get_redis()
        await r.ping()
    except Exception as e:
        checks["redis"] = f"error: {e}"

    all_ok = all(v == "ok" for v in checks.values())

    return JSONResponse(
        status_code=200 if all_ok else 503,
        content={
            "status":      "healthy" if all_ok else "degraded",
            "app":         settings.APP_NAME,
            "version":     settings.APP_VERSION,
            "environment": settings.ENVIRONMENT,
            "checks":      checks,
        },
    )


@app.get("/", tags=["System"])
async def root():
    return {
        "app":     "MiskMatch API",
        "version": settings.APP_VERSION,
        "docs":    "/docs" if not settings.is_production else None,
        "tagline": "Sealed with musk. — ختامه مسك",
    }
