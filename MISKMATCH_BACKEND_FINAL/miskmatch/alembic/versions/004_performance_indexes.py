"""
004 — Performance Indexes
Adds composite indexes identified during performance optimization:

- matches(sender_id, status) + matches(receiver_id, status)
  → Speeds up GET /matches (my matches list) filtered by status
- matches(sender_id, created_at) for monthly interest count
  → Speeds up express_interest free-tier limit check
- messages(match_id, sender_id) for sender name lookups
  → Speeds up message history enrichment

Run:  alembic upgrade head
Down: alembic downgrade -1
"""

from alembic import op

revision      = "004_performance_indexes"
down_revision = "003_compatibility_engine"
branch_labels = None
depends_on    = None


def upgrade() -> None:
    # Matches: user's match list filtered by status
    op.create_index(
        "ix_matches_sender_status",
        "matches",
        ["sender_id", "status", "updated_at"],
    )
    op.create_index(
        "ix_matches_receiver_status",
        "matches",
        ["receiver_id", "status", "updated_at"],
    )

    # Matches: monthly interest count for rate limiting
    op.create_index(
        "ix_matches_sender_created",
        "matches",
        ["sender_id", "created_at"],
    )

    # Messages: batch sender name lookups
    op.create_index(
        "ix_messages_sender",
        "messages",
        ["sender_id"],
    )

    # Wali relationships: lookup by ward (used in wali pending)
    op.create_index(
        "ix_wali_user_active",
        "wali_relationships",
        ["user_id", "is_active"],
    )


def downgrade() -> None:
    op.drop_index("ix_wali_user_active", table_name="wali_relationships")
    op.drop_index("ix_messages_sender", table_name="messages")
    op.drop_index("ix_matches_sender_created", table_name="matches")
    op.drop_index("ix_matches_receiver_status", table_name="matches")
    op.drop_index("ix_matches_sender_status", table_name="matches")
