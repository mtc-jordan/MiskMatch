"""
001 — Initial Schema
MiskMatch complete database schema.

Creates:
  - 14 PostgreSQL ENUM types
  - 12 tables (dependency-ordered)
  - 8 indexes for query performance
  - 3 check constraints (age, trust_score)
  - All foreign keys with CASCADE rules

Run:  alembic upgrade head
Down: alembic downgrade base
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# ── Revision metadata ─────────────────────────────────────────────────────────
revision = "001_initial_schema"
down_revision = None
branch_labels = None
depends_on = None


# ── ENUM definitions ──────────────────────────────────────────────────────────
ENUMS = {
    "userrole": ["user", "wali", "admin", "scholar"],
    "userstatus": ["pending", "active", "suspended", "banned", "deactivated"],
    "gender": ["male", "female"],
    "verificationstatus": ["none", "pending", "verified", "failed", "expired"],
    "subscriptiontier": ["barakah", "noor", "misk"],
    "matchstatus": ["pending", "mutual", "approved", "active", "nikah", "closed", "blocked"],
    "gametype": [
        "qalb_quiz", "would_you_rather", "finish_sentence", "values_map",
        "islamic_trivia", "quran_ayah", "geography_race", "hadith_match",
        "build_story", "dream_home", "time_capsule",
        "honesty_box", "priority_rank", "love_languages", "questions_36",
        "family_trivia", "deal_no_deal",
    ],
    "gamestatus": ["active", "waiting", "completed", "expired", "sealed"],
    "messagestatus": ["sent", "delivered", "read", "flagged"],
    "calltype": ["audio", "video", "video_chaperoned"],
    "madhabchoice": ["hanafi", "maliki", "shafii", "hanbali", "other"],
    "prayerfrequency": ["all_five", "most", "sometimes", "friday_only", "working_on"],
    "hijabstance": ["wears", "open_to", "family_decides", "preference", "na"],
}


def upgrade() -> None:
    # ── 1. Create all ENUM types ──────────────────────────────────────────────
    for name, values in ENUMS.items():
        enum_type = postgresql.ENUM(*values, name=name)
        enum_type.create(op.get_bind(), checkfirst=True)

    # ── 2. mosques (no FK deps) ───────────────────────────────────────────────
    op.create_table(
        "mosques",
        sa.Column("id",                   postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("name",                 sa.String(200),  nullable=False),
        sa.Column("name_ar",              sa.String(200),  nullable=True),
        sa.Column("country",              sa.String(2),    nullable=False),
        sa.Column("city",                 sa.String(100),  nullable=False),
        sa.Column("address",              sa.Text(),       nullable=True),
        sa.Column("phone",                sa.String(20),   nullable=True),
        sa.Column("email",                sa.String(255),  nullable=True),
        sa.Column("website",              sa.String(500),  nullable=True),
        sa.Column("imam_name",            sa.String(100),  nullable=True),
        sa.Column("is_partner",           sa.Boolean(),    nullable=False, server_default="false"),
        sa.Column("is_verified",          sa.Boolean(),    nullable=False, server_default="false"),
        sa.Column("partner_since",        sa.DateTime(timezone=True), nullable=True),
        sa.Column("verified_member_count",sa.Integer(),    nullable=False, server_default="0"),
        sa.Column("created_at",           sa.DateTime(timezone=True), nullable=False,
                  server_default=sa.text("now()")),
        sa.Column("updated_at",           sa.DateTime(timezone=True), nullable=False,
                  server_default=sa.text("now()")),
    )

    # ── 3. users ──────────────────────────────────────────────────────────────
    op.create_table(
        "users",
        sa.Column("id",                      postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("email",                   sa.String(255), nullable=True, unique=True),
        sa.Column("phone",                   sa.String(20),  nullable=False, unique=True),
        sa.Column("password_hash",           sa.String(255), nullable=False),
        sa.Column("role",                    sa.Enum("user","wali","admin","scholar", name="userrole"),
                  nullable=False, server_default="user"),
        sa.Column("status",                  sa.Enum("pending","active","suspended","banned","deactivated",
                  name="userstatus"), nullable=False, server_default="pending"),
        sa.Column("gender",                  sa.Enum("male","female", name="gender"), nullable=False),
        sa.Column("email_verified",          sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("phone_verified",          sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("id_verified",             sa.Enum("none","pending","verified","failed","expired",
                  name="verificationstatus"), nullable=False, server_default="none"),
        sa.Column("onfido_applicant_id",     sa.String(100), nullable=True),
        sa.Column("subscription_tier",       sa.Enum("barakah","noor","misk",
                  name="subscriptiontier"), nullable=False, server_default="barakah"),
        sa.Column("subscription_expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("stripe_customer_id",      sa.String(100), nullable=True),
        sa.Column("last_seen_at",            sa.DateTime(timezone=True), nullable=True),
        sa.Column("niyyah",                  sa.Text(),      nullable=True),
        sa.Column("onboarding_completed",    sa.Boolean(),   nullable=False, server_default="false"),
        sa.Column("ramadan_mode",            sa.Boolean(),   nullable=False, server_default="false"),
        sa.Column("fcm_token",               sa.String(500), nullable=True),
        sa.Column("deleted_at",              sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at",              sa.DateTime(timezone=True), nullable=False,
                  server_default=sa.text("now()")),
        sa.Column("updated_at",              sa.DateTime(timezone=True), nullable=False,
                  server_default=sa.text("now()")),
    )
    op.create_index("ix_users_email",         "users", ["email"],  unique=True)
    op.create_index("ix_users_phone",         "users", ["phone"],  unique=True)
    op.create_index("ix_users_status_gender", "users", ["status", "gender"])
    op.create_index("ix_users_deleted_at",    "users", ["deleted_at"])

    # ── 4. profiles (FK → users, mosques) ────────────────────────────────────
    op.create_table(
        "profiles",
        sa.Column("id",                      postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id",                 postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False, unique=True),
        sa.Column("first_name",              sa.String(50),  nullable=False),
        sa.Column("last_name",               sa.String(50),  nullable=False),
        sa.Column("display_name",            sa.String(100), nullable=True),
        sa.Column("date_of_birth",           sa.DateTime(timezone=True), nullable=True),
        sa.Column("city",                    sa.String(100), nullable=True),
        sa.Column("country",                 sa.String(2),   nullable=True),
        sa.Column("nationality",             sa.String(2),   nullable=True),
        sa.Column("languages",               postgresql.ARRAY(sa.String()), nullable=True),
        sa.Column("bio",                     sa.Text(),      nullable=True),
        sa.Column("bio_ar",                  sa.Text(),      nullable=True),
        sa.Column("photo_url",               sa.String(500), nullable=True),
        sa.Column("photos",                  postgresql.ARRAY(sa.String()), nullable=True),
        sa.Column("voice_intro_url",         sa.String(500), nullable=True),
        sa.Column("photo_visible",           sa.Boolean(),   nullable=False, server_default="false"),
        sa.Column("madhab",                  sa.Enum("hanafi","maliki","shafii","hanbali","other",
                  name="madhabchoice"), nullable=True),
        sa.Column("prayer_frequency",        sa.Enum("all_five","most","sometimes","friday_only",
                  "working_on", name="prayerfrequency"), nullable=True),
        sa.Column("hijab_stance",            sa.Enum("wears","open_to","family_decides","preference","na",
                  name="hijabstance"), nullable=True),
        sa.Column("quran_level",             sa.String(50),  nullable=True),
        sa.Column("quran_recitation_url",    sa.String(500), nullable=True),
        sa.Column("is_revert",               sa.Boolean(),   nullable=False, server_default="false"),
        sa.Column("revert_year",             sa.Integer(),   nullable=True),
        sa.Column("education_level",         sa.String(100), nullable=True),
        sa.Column("field_of_study",          sa.String(100), nullable=True),
        sa.Column("occupation",              sa.String(100), nullable=True),
        sa.Column("employer",                sa.String(100), nullable=True),
        sa.Column("income_range",            sa.String(50),  nullable=True),
        sa.Column("wants_children",          sa.Boolean(),   nullable=True),
        sa.Column("num_children_desired",    sa.String(20),  nullable=True),
        sa.Column("children_schooling",      sa.String(50),  nullable=True),
        sa.Column("hajj_timeline",           sa.String(50),  nullable=True),
        sa.Column("wants_hijra",             sa.Boolean(),   nullable=True),
        sa.Column("hijra_country",           sa.String(100), nullable=True),
        sa.Column("islamic_finance_stance",  sa.String(50),  nullable=True),
        sa.Column("wife_working_stance",     sa.String(50),  nullable=True),
        sa.Column("sifr_scores",             postgresql.JSON(astext_type=sa.Text()), nullable=True),
        sa.Column("love_language",           sa.String(50),  nullable=True),
        sa.Column("priority_ranking",        postgresql.ARRAY(sa.String()), nullable=True),
        sa.Column("compatibility_embedding", postgresql.ARRAY(sa.Float()), nullable=True),
        sa.Column("deen_score",              sa.Float(),     nullable=True),
        sa.Column("min_age",                 sa.Integer(),   nullable=False, server_default="22"),
        sa.Column("max_age",                 sa.Integer(),   nullable=False, server_default="40"),
        sa.Column("preferred_countries",     postgresql.ARRAY(sa.String()), nullable=True),
        sa.Column("max_distance_km",         sa.Integer(),   nullable=True),
        sa.Column("mosque_verified",         sa.Boolean(),   nullable=False, server_default="false"),
        sa.Column("mosque_id",               postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("mosques.id"), nullable=True),
        sa.Column("scholar_endorsed",        sa.Boolean(),   nullable=False, server_default="false"),
        sa.Column("trust_score",             sa.Integer(),   nullable=False, server_default="0"),
        sa.Column("created_at",              sa.DateTime(timezone=True), nullable=False,
                  server_default=sa.text("now()")),
        sa.Column("updated_at",              sa.DateTime(timezone=True), nullable=False,
                  server_default=sa.text("now()")),
        sa.CheckConstraint("min_age >= 18 AND min_age <= 80", name="ck_profile_min_age"),
        sa.CheckConstraint("max_age >= 18 AND max_age <= 80", name="ck_profile_max_age"),
        sa.CheckConstraint("trust_score >= 0 AND trust_score <= 100", name="ck_profile_trust"),
    )
    op.create_index("ix_profiles_user_id",      "profiles", ["user_id"])
    op.create_index("ix_profiles_country_city", "profiles", ["country", "city"])

    # ── 5. families ───────────────────────────────────────────────────────────
    op.create_table(
        "families",
        sa.Column("id",                   postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id",              postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False, unique=True),
        sa.Column("family_origin",        sa.String(100), nullable=True),
        sa.Column("family_type",          sa.String(50),  nullable=True),
        sa.Column("num_siblings",         sa.Integer(),   nullable=True),
        sa.Column("family_religiosity",   sa.String(50),  nullable=True),
        sa.Column("father_occupation",    sa.String(100), nullable=True),
        sa.Column("mother_occupation",    sa.String(100), nullable=True),
        sa.Column("family_description",   sa.Text(),      nullable=True),
        sa.Column("family_description_ar",sa.Text(),      nullable=True),
        sa.Column("family_values",        sa.Text(),      nullable=True),
        sa.Column("family_trivia",        postgresql.JSON(astext_type=sa.Text()), nullable=True),
        sa.Column("living_arrangement",   sa.String(50),  nullable=True),
        sa.Column("family_involvement",   sa.String(50),  nullable=True),
        sa.Column("created_at",           sa.DateTime(timezone=True), nullable=False,
                  server_default=sa.text("now()")),
        sa.Column("updated_at",           sa.DateTime(timezone=True), nullable=False,
                  server_default=sa.text("now()")),
    )

    # ── 6. wali_relationships ─────────────────────────────────────────────────
    op.create_table(
        "wali_relationships",
        sa.Column("id",                  postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id",             postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False, unique=True),
        sa.Column("wali_name",           sa.String(100), nullable=False),
        sa.Column("wali_phone",          sa.String(20),  nullable=False),
        sa.Column("wali_relationship",   sa.String(50),  nullable=False),
        sa.Column("wali_user_id",        postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("users.id"), nullable=True),
        sa.Column("is_active",           sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("invitation_sent",     sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("invitation_accepted", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("invited_at",          sa.DateTime(timezone=True), nullable=True),
        sa.Column("accepted_at",         sa.DateTime(timezone=True), nullable=True),
        sa.Column("can_view_matches",    sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("can_view_messages",   sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("can_approve_matches", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("can_join_calls",      sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("created_at",          sa.DateTime(timezone=True), nullable=False,
                  server_default=sa.text("now()")),
        sa.Column("updated_at",          sa.DateTime(timezone=True), nullable=False,
                  server_default=sa.text("now()")),
    )
    op.create_index("ix_wali_user_id",      "wali_relationships", ["user_id"])
    op.create_index("ix_wali_wali_user_id", "wali_relationships", ["wali_user_id"])

    # ── 7. matches ────────────────────────────────────────────────────────────
    op.create_table(
        "matches",
        sa.Column("id",                       postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("sender_id",                postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("receiver_id",              postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("status",                   sa.Enum("pending","mutual","approved","active",
                  "nikah","closed","blocked", name="matchstatus"),
                  nullable=False, server_default="pending"),
        sa.Column("sender_message",           sa.Text(),  nullable=True),
        sa.Column("receiver_response",        sa.Text(),  nullable=True),
        sa.Column("sender_wali_approved",     sa.Boolean(), nullable=True),
        sa.Column("receiver_wali_approved",   sa.Boolean(), nullable=True),
        sa.Column("sender_wali_approved_at",  sa.DateTime(timezone=True), nullable=True),
        sa.Column("receiver_wali_approved_at",sa.DateTime(timezone=True), nullable=True),
        sa.Column("compatibility_score",      sa.Float(),  nullable=True),
        sa.Column("compatibility_breakdown",  postgresql.JSON(astext_type=sa.Text()), nullable=True),
        sa.Column("became_mutual_at",         sa.DateTime(timezone=True), nullable=True),
        sa.Column("nikah_date",               sa.DateTime(timezone=True), nullable=True),
        sa.Column("closed_reason",            sa.String(100), nullable=True),
        sa.Column("match_memory",             postgresql.JSON(astext_type=sa.Text()), nullable=True),
        sa.Column("game_states",              postgresql.JSON(astext_type=sa.Text()), nullable=True),
        sa.Column("memory_timeline",          postgresql.JSON(astext_type=sa.Text()), nullable=True),
        sa.Column("created_at",               sa.DateTime(timezone=True), nullable=False,
                  server_default=sa.text("now()")),
        sa.Column("updated_at",               sa.DateTime(timezone=True), nullable=False,
                  server_default=sa.text("now()")),
        sa.UniqueConstraint("sender_id", "receiver_id", name="uq_match_pair"),
    )
    op.create_index("ix_matches_sender_id",   "matches", ["sender_id"])
    op.create_index("ix_matches_receiver_id", "matches", ["receiver_id"])
    op.create_index("ix_matches_status",      "matches", ["status"])

    # ── 8. messages ───────────────────────────────────────────────────────────
    op.create_table(
        "messages",
        sa.Column("id",                 postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("match_id",           postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("matches.id", ondelete="CASCADE"), nullable=False),
        sa.Column("sender_id",          postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("users.id",   ondelete="CASCADE"), nullable=False),
        sa.Column("content",            sa.Text(),     nullable=False),
        sa.Column("content_type",       sa.String(20), nullable=False, server_default="text"),
        sa.Column("media_url",          sa.String(500),nullable=True),
        sa.Column("status",             sa.Enum("sent","delivered","read","flagged",
                  name="messagestatus"), nullable=False, server_default="sent"),
        sa.Column("moderation_passed",  sa.Boolean(),  nullable=True),
        sa.Column("moderation_reason",  sa.String(200),nullable=True),
        sa.Column("created_at",         sa.DateTime(timezone=True), nullable=False,
                  server_default=sa.text("now()")),
        sa.Column("updated_at",         sa.DateTime(timezone=True), nullable=False,
                  server_default=sa.text("now()")),
    )
    op.create_index("ix_messages_match_id",       "messages", ["match_id"])
    op.create_index("ix_messages_sender_id",      "messages", ["sender_id"])
    op.create_index("ix_messages_match_created",  "messages", ["match_id", "created_at"])

    # ── 9. games ──────────────────────────────────────────────────────────────
    op.create_table(
        "games",
        sa.Column("id",                   postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("match_id",             postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("matches.id", ondelete="CASCADE"), nullable=False),
        sa.Column("game_type",            sa.Enum(
                  "qalb_quiz","would_you_rather","finish_sentence","values_map",
                  "islamic_trivia","quran_ayah","geography_race","hadith_match",
                  "build_story","dream_home","time_capsule","honesty_box",
                  "priority_rank","love_languages","questions_36","family_trivia","deal_no_deal",
                  name="gametype"), nullable=False),
        sa.Column("status",               sa.Enum("active","waiting","completed","expired","sealed",
                  name="gamestatus"), nullable=False, server_default="active"),
        sa.Column("current_turn_user_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("game_data",            postgresql.JSON(astext_type=sa.Text()), nullable=True),
        sa.Column("player1_answers",      postgresql.JSON(astext_type=sa.Text()), nullable=True),
        sa.Column("player2_answers",      postgresql.JSON(astext_type=sa.Text()), nullable=True),
        sa.Column("results",              postgresql.JSON(astext_type=sa.Text()), nullable=True),
        sa.Column("compatibility_delta",  sa.Float(), nullable=True),
        sa.Column("sealed_at",            sa.DateTime(timezone=True), nullable=True),
        sa.Column("reveals_at",           sa.DateTime(timezone=True), nullable=True),
        sa.Column("expires_at",           sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at",           sa.DateTime(timezone=True), nullable=False,
                  server_default=sa.text("now()")),
        sa.Column("updated_at",           sa.DateTime(timezone=True), nullable=False,
                  server_default=sa.text("now()")),
    )
    op.create_index("ix_games_match_id", "games", ["match_id"])

    # ── 10. calls ─────────────────────────────────────────────────────────────
    op.create_table(
        "calls",
        sa.Column("id",                 postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("match_id",           postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("matches.id", ondelete="CASCADE"), nullable=False),
        sa.Column("initiator_id",       postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("users.id"), nullable=False),
        sa.Column("call_type",          sa.Enum("audio","video","video_chaperoned",
                  name="calltype"), nullable=False),
        sa.Column("agora_channel",      sa.String(100), nullable=False),
        sa.Column("agora_token",        sa.String(500), nullable=True),
        sa.Column("wali_invited",       sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("wali_joined",        sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("wali_approved",      sa.Boolean(), nullable=True),
        sa.Column("scheduled_at",       sa.DateTime(timezone=True), nullable=True),
        sa.Column("started_at",         sa.DateTime(timezone=True), nullable=True),
        sa.Column("ended_at",           sa.DateTime(timezone=True), nullable=True),
        sa.Column("duration_seconds",   sa.Integer(), nullable=True),
        sa.Column("recording_url",      sa.String(500), nullable=True),
        sa.Column("recording_consent",  sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("created_at",         sa.DateTime(timezone=True), nullable=False,
                  server_default=sa.text("now()")),
        sa.Column("updated_at",         sa.DateTime(timezone=True), nullable=False,
                  server_default=sa.text("now()")),
    )
    op.create_index("ix_calls_match_id", "calls", ["match_id"])

    # ── 11. notifications ─────────────────────────────────────────────────────
    op.create_table(
        "notifications",
        sa.Column("id",                postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id",           postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("title",             sa.String(200), nullable=False),
        sa.Column("title_ar",          sa.String(200), nullable=True),
        sa.Column("body",              sa.Text(),      nullable=False),
        sa.Column("body_ar",           sa.Text(),      nullable=True),
        sa.Column("notification_type", sa.String(50),  nullable=False),
        sa.Column("reference_id",      postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("reference_type",    sa.String(50),  nullable=True),
        sa.Column("is_read",           sa.Boolean(),   nullable=False, server_default="false"),
        sa.Column("read_at",           sa.DateTime(timezone=True), nullable=True),
        sa.Column("push_sent",         sa.Boolean(),   nullable=False, server_default="false"),
        sa.Column("created_at",        sa.DateTime(timezone=True), nullable=False,
                  server_default=sa.text("now()")),
        sa.Column("updated_at",        sa.DateTime(timezone=True), nullable=False,
                  server_default=sa.text("now()")),
    )
    op.create_index("ix_notifications_user_id",    "notifications", ["user_id"])
    op.create_index("ix_notifications_user_unread","notifications", ["user_id", "is_read"])

    # ── 12. subscriptions ─────────────────────────────────────────────────────
    op.create_table(
        "subscriptions",
        sa.Column("id",                      postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id",                 postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("tier",                    sa.Enum("barakah","noor","misk",
                  name="subscriptiontier"), nullable=False),
        sa.Column("stripe_subscription_id",  sa.String(100), nullable=True),
        sa.Column("stripe_payment_intent_id",sa.String(100), nullable=True),
        sa.Column("amount_cents",            sa.Integer(),   nullable=False),
        sa.Column("currency",                sa.String(3),   nullable=False, server_default="USD"),
        sa.Column("status",                  sa.String(30),  nullable=False),
        sa.Column("starts_at",               sa.DateTime(timezone=True), nullable=False),
        sa.Column("ends_at",                 sa.DateTime(timezone=True), nullable=True),
        sa.Column("cancelled_at",            sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at",              sa.DateTime(timezone=True), nullable=False,
                  server_default=sa.text("now()")),
        sa.Column("updated_at",              sa.DateTime(timezone=True), nullable=False,
                  server_default=sa.text("now()")),
    )
    op.create_index("ix_subscriptions_user_id", "subscriptions", ["user_id"])

    # ── 13. reports ───────────────────────────────────────────────────────────
    op.create_table(
        "reports",
        sa.Column("id",           postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("reporter_id",  postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("users.id"), nullable=False),
        sa.Column("reported_id",  postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("users.id"), nullable=False),
        sa.Column("reason",       sa.String(100), nullable=False),
        sa.Column("description",  sa.Text(),      nullable=True),
        sa.Column("evidence_urls",postgresql.ARRAY(sa.String()), nullable=True),
        sa.Column("is_block",     sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("status",       sa.String(30), nullable=False, server_default="pending"),
        sa.Column("reviewed_by",  postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("reviewed_at",  sa.DateTime(timezone=True), nullable=True),
        sa.Column("resolution",   sa.Text(), nullable=True),
        sa.Column("created_at",   sa.DateTime(timezone=True), nullable=False,
                  server_default=sa.text("now()")),
        sa.Column("updated_at",   sa.DateTime(timezone=True), nullable=False,
                  server_default=sa.text("now()")),
    )
    op.create_index("ix_reports_reporter_id", "reports", ["reporter_id"])
    op.create_index("ix_reports_reported_id", "reports", ["reported_id"])


def downgrade() -> None:
    # Drop tables in reverse dependency order
    for table in [
        "reports", "subscriptions", "notifications",
        "calls", "games", "messages",
        "matches", "wali_relationships", "families",
        "profiles", "users", "mosques",
    ]:
        op.drop_table(table)

    # Drop all ENUMs
    for name in ENUMS:
        op.execute(f"DROP TYPE IF EXISTS {name} CASCADE")
