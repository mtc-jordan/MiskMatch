"""
003 — Compatibility Engine Infrastructure
Adds deen_score index and documents the pgvector upgrade path.

The compatibility_embedding column (ARRAY Float) was created in 001.
This migration adds supporting indexes and the deen_score computed column.

Production upgrade path (when user base grows):
  1. Install pgvector: CREATE EXTENSION vector
  2. ALTER TABLE profiles ADD COLUMN embedding_v2 vector(1536)
  3. Migrate data: UPDATE profiles SET embedding_v2 = compatibility_embedding::vector
  4. CREATE INDEX ON profiles USING ivfflat (embedding_v2 vector_cosine_ops) WITH (lists=100)
  5. Drop old column after validation

At 10k profiles, Python cosine similarity is fast enough (<100ms for full scan).
At 100k+, use pgvector IVFFlat for approximate nearest neighbour in <5ms.

Run:  alembic upgrade head
Down: alembic downgrade -1
"""

from alembic import op
import sqlalchemy as sa

revision      = "003_compatibility_engine"
down_revision = "002_wali_portal_indexes"
branch_labels = None
depends_on    = None


def upgrade() -> None:
    # Index on deen_score for fast "top deen score" sorting in discovery
    op.create_index(
        "ix_profiles_deen_score",
        "profiles",
        ["deen_score"],
        postgresql_where=sa.text("deen_score IS NOT NULL"),
    )

    # Index on trust_score for discovery tiebreaker sorting
    op.create_index(
        "ix_profiles_trust_score",
        "profiles",
        ["trust_score"],
    )

    # Composite index for discovery candidate query
    # (gender filter + country + not already matched)
    op.create_index(
        "ix_profiles_discovery",
        "profiles",
        ["country", "trust_score", "mosque_verified"],
    )

    # Index on embedding presence — fast check for stale-embed job
    # PostgreSQL partial index: only profiles WITH an embedding
    op.execute("""
        CREATE INDEX IF NOT EXISTS ix_profiles_has_embedding
        ON profiles ((compatibility_embedding IS NOT NULL))
        WHERE compatibility_embedding IS NOT NULL
    """)


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_profiles_has_embedding")
    op.drop_index("ix_profiles_discovery",  table_name="profiles")
    op.drop_index("ix_profiles_trust_score", table_name="profiles")
    op.drop_index("ix_profiles_deen_score",  table_name="profiles")
