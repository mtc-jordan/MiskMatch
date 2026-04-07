"""
002 — Wali Portal indexes
Adds performance indexes for common wali portal queries.

The wali_relationships table was created in 001.
This migration adds composite indexes needed for the
dashboard and pending-decisions queries.

Run:  alembic upgrade head
Down: alembic downgrade -1
"""

from alembic import op
import sqlalchemy as sa

revision      = "002_wali_portal_indexes"
down_revision = "001_initial_schema"
branch_labels = None
depends_on    = None


def upgrade() -> None:
    # Fast lookup: find all active accepted walis for a given wali_user_id
    op.create_index(
        "ix_wali_active_accepted",
        "wali_relationships",
        ["wali_user_id", "is_active", "invitation_accepted"],
    )

    # Fast lookup: find active wali for a given ward
    op.create_index(
        "ix_wali_ward_active",
        "wali_relationships",
        ["user_id", "is_active"],
    )

    # Fast lookup: pending match decisions
    # (matches in MUTUAL status needing wali approval)
    op.create_index(
        "ix_matches_mutual_status",
        "matches",
        ["status", "sender_wali_approved", "receiver_wali_approved"],
    )

    # Notification type index for wali-specific alerts
    op.create_index(
        "ix_notifications_type",
        "notifications",
        ["user_id", "notification_type", "is_read"],
    )


def downgrade() -> None:
    op.drop_index("ix_notifications_type",     table_name="notifications")
    op.drop_index("ix_matches_mutual_status",  table_name="matches")
    op.drop_index("ix_wali_ward_active",       table_name="wali_relationships")
    op.drop_index("ix_wali_active_accepted",   table_name="wali_relationships")
