"""
005 — Referential Integrity
Adds missing ondelete rules to foreign keys and indexes on FK columns
that were missing them. Ensures proper cascade/nullify behaviour when
parent rows are deleted.

Changes:
  - wali_relationships.wali_user_id   → ON DELETE SET NULL
  - profiles.mosque_id                → ON DELETE SET NULL
  - calls.initiator_id                → ON DELETE CASCADE + index
  - reports.reporter_id               → ON DELETE CASCADE + index
  - reports.reported_id               → ON DELETE CASCADE + index
  - reports.reviewed_by               → new FK to users.id ON DELETE SET NULL
  - games.current_turn_user_id        → new FK to users.id ON DELETE SET NULL

Run:  alembic upgrade head
Down: alembic downgrade -1
"""

from alembic import op

revision      = "005_referential_integrity"
down_revision = "004_performance_indexes"
branch_labels = None
depends_on    = None


# ── Helpers ──────────────────────────────────────────────────────────────────

def _replace_fk(table: str, column: str, ref_table: str, ondelete: str, constraint_name: str):
    """Drop the old FK (no ondelete) and recreate with the correct rule."""
    # Drop existing FK — naming convention: <table>_<column>_fkey
    old_name = f"{table}_{column}_fkey"
    op.drop_constraint(old_name, table, type_="foreignkey")
    op.create_foreign_key(
        constraint_name, table, ref_table,
        [column], ["id"],
        ondelete=ondelete,
    )


# ── Upgrade ──────────────────────────────────────────────────────────────────

def upgrade() -> None:
    # 1. wali_relationships.wali_user_id → SET NULL
    _replace_fk(
        "wali_relationships", "wali_user_id", "users",
        ondelete="SET NULL",
        constraint_name="fk_wali_relationships_wali_user_id",
    )

    # 2. profiles.mosque_id → SET NULL
    _replace_fk(
        "profiles", "mosque_id", "mosques",
        ondelete="SET NULL",
        constraint_name="fk_profiles_mosque_id",
    )

    # 3. calls.initiator_id → CASCADE + add index
    _replace_fk(
        "calls", "initiator_id", "users",
        ondelete="CASCADE",
        constraint_name="fk_calls_initiator_id",
    )
    op.create_index("ix_calls_initiator_id", "calls", ["initiator_id"])

    # 4. reports.reporter_id → CASCADE + add index
    _replace_fk(
        "reports", "reporter_id", "users",
        ondelete="CASCADE",
        constraint_name="fk_reports_reporter_id",
    )
    op.create_index("ix_reports_reporter_id", "reports", ["reporter_id"])

    # 5. reports.reported_id → CASCADE + add index
    _replace_fk(
        "reports", "reported_id", "users",
        ondelete="CASCADE",
        constraint_name="fk_reports_reported_id",
    )
    op.create_index("ix_reports_reported_id", "reports", ["reported_id"])

    # 6. reports.reviewed_by → new FK to users (was bare UUID)
    op.create_foreign_key(
        "fk_reports_reviewed_by", "reports", "users",
        ["reviewed_by"], ["id"],
        ondelete="SET NULL",
    )

    # 7. games.current_turn_user_id → new FK to users (was bare UUID)
    op.create_foreign_key(
        "fk_games_current_turn_user_id", "games", "users",
        ["current_turn_user_id"], ["id"],
        ondelete="SET NULL",
    )


# ── Downgrade ────────────────────────────────────────────────────────────────

def downgrade() -> None:
    # 7. Remove games FK
    op.drop_constraint("fk_games_current_turn_user_id", "games", type_="foreignkey")

    # 6. Remove reports.reviewed_by FK
    op.drop_constraint("fk_reports_reviewed_by", "reports", type_="foreignkey")

    # 5. reports.reported_id → restore original FK without ondelete
    op.drop_index("ix_reports_reported_id", "reports")
    op.drop_constraint("fk_reports_reported_id", "reports", type_="foreignkey")
    op.create_foreign_key(
        "reports_reported_id_fkey", "reports", "users",
        ["reported_id"], ["id"],
    )

    # 4. reports.reporter_id → restore original FK without ondelete
    op.drop_index("ix_reports_reporter_id", "reports")
    op.drop_constraint("fk_reports_reporter_id", "reports", type_="foreignkey")
    op.create_foreign_key(
        "reports_reporter_id_fkey", "reports", "users",
        ["reporter_id"], ["id"],
    )

    # 3. calls.initiator_id → restore original FK without ondelete
    op.drop_index("ix_calls_initiator_id", "calls")
    op.drop_constraint("fk_calls_initiator_id", "calls", type_="foreignkey")
    op.create_foreign_key(
        "calls_initiator_id_fkey", "calls", "users",
        ["initiator_id"], ["id"],
    )

    # 2. profiles.mosque_id → restore original FK without ondelete
    op.drop_constraint("fk_profiles_mosque_id", "profiles", type_="foreignkey")
    op.create_foreign_key(
        "profiles_mosque_id_fkey", "profiles", "mosques",
        ["mosque_id"], ["id"],
    )

    # 1. wali_relationships.wali_user_id → restore original FK without ondelete
    op.drop_constraint("fk_wali_relationships_wali_user_id", "wali_relationships", type_="foreignkey")
    op.create_foreign_key(
        "wali_relationships_wali_user_id_fkey", "wali_relationships", "users",
        ["wali_user_id"], ["id"],
    )
