"""
MiskMatch — Database Configuration
Async SQLAlchemy with PostgreSQL via asyncpg.
"""

from typing import AsyncGenerator
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase
from sqlalchemy import MetaData

from app.core.config import settings

# ─────────────────────────────────────────────
# Naming convention for Alembic migrations
# ─────────────────────────────────────────────
NAMING_CONVENTION = {
    "ix": "ix_%(column_0_label)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
}

# ─────────────────────────────────────────────
# Engine — async, connection pooled
# ─────────────────────────────────────────────
engine = create_async_engine(
    settings.DATABASE_URL,
    pool_size=settings.DB_POOL_SIZE,
    max_overflow=settings.DB_MAX_OVERFLOW,
    pool_pre_ping=True,       # test connections before use
    pool_recycle=1800,         # recycle connections every 30 min (avoid stale)
    pool_timeout=30,           # wait max 30s for a connection from pool
    echo=settings.DEBUG,       # log SQL in dev only
    # Statement cache for asyncpg — reduces parse overhead on repeated queries
    connect_args={"statement_cache_size": 100},
)

# ─────────────────────────────────────────────
# Session factory
# ─────────────────────────────────────────────
AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,   # keep objects usable after commit
    autoflush=False,
    autocommit=False,
)

# ─────────────────────────────────────────────
# Base model class
# ─────────────────────────────────────────────
class Base(DeclarativeBase):
    metadata = MetaData(naming_convention=NAMING_CONVENTION)


# ─────────────────────────────────────────────
# Dependency — inject DB session into routes
# ─────────────────────────────────────────────
async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """
    FastAPI dependency that provides an async DB session.
    Automatically commits on success, rolls back on error.

    Usage:
        @router.get("/")
        async def endpoint(db: AsyncSession = Depends(get_db)):
            ...
    """
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()
