"""
MiskMatch — Integration Test Configuration (PostgreSQL)

Usage:
  Set USE_REAL_DB=1 and provide DATABASE_URL pointing to a real PostgreSQL
  instance to run integration tests against a live database.

  pytest tests/ -m integration --override-ini="asyncio_mode=auto"

Without USE_REAL_DB=1, integration-marked tests are automatically skipped.
"""

import os
import pytest
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession

from app.core.database import Base

# Skip all integration tests unless explicitly enabled
USE_REAL_DB = os.environ.get("USE_REAL_DB", "0") == "1"

skip_without_db = pytest.mark.skipif(
    not USE_REAL_DB,
    reason="Integration tests require USE_REAL_DB=1 and a PostgreSQL instance",
)


@pytest.fixture(scope="session")
def integration_engine():
    """Create a real async engine for integration tests."""
    if not USE_REAL_DB:
        pytest.skip("USE_REAL_DB not set")

    db_url = os.environ.get(
        "DATABASE_URL",
        "postgresql+asyncpg://miskmatch:miskmatch@localhost:5433/miskmatch_test",
    )
    engine = create_async_engine(db_url, echo=False)
    yield engine


@pytest.fixture(scope="session")
async def setup_integration_db(integration_engine):
    """Create all tables in the test database, drop them after the session."""
    async with integration_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with integration_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


@pytest.fixture
async def integration_db(integration_engine, setup_integration_db):
    """Provide a real async session, rolled back after each test."""
    session_factory = async_sessionmaker(
        bind=integration_engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )
    async with session_factory() as session:
        async with session.begin():
            yield session
            await session.rollback()
