"""
MiskMatch — Complete Database Models
All tables for the Islamic matrimony platform.
"Sealed with musk." — ختامه مسك — Quran 83:26
"""

import uuid
from datetime import datetime, timezone
from enum import Enum as PyEnum
from typing import List, Optional

from sqlalchemy import (
    Boolean, Column, DateTime, Enum, Float, ForeignKey,
    Integer, JSON, String, Text, UniqueConstraint,
    CheckConstraint, Index,
)
from sqlalchemy.dialects.postgresql import UUID, ARRAY
from sqlalchemy.orm import relationship, Mapped, mapped_column
from sqlalchemy.sql import func

from app.core.database import Base


# ─────────────────────────────────────────────
# ENUMS
# ─────────────────────────────────────────────

class UserRole(str, PyEnum):
    USER    = "user"
    WALI    = "wali"          # guardian
    ADMIN   = "admin"
    SCHOLAR = "scholar"       # verified Islamic scholar

class UserStatus(str, PyEnum):
    PENDING     = "pending"   # registered, not verified
    ACTIVE      = "active"    # fully verified and active
    SUSPENDED   = "suspended" # temporarily suspended
    BANNED      = "banned"    # permanently banned
    DEACTIVATED = "deactivated"

class Gender(str, PyEnum):
    MALE   = "male"
    FEMALE = "female"

class VerificationStatus(str, PyEnum):
    NONE       = "none"
    PENDING    = "pending"
    VERIFIED   = "verified"
    FAILED     = "failed"
    EXPIRED    = "expired"

class SubscriptionTier(str, PyEnum):
    BARAKAH = "barakah"  # free
    NOOR    = "noor"     # $19.99/mo
    MISK    = "misk"     # $39.99/mo

class MatchStatus(str, PyEnum):
    PENDING   = "pending"    # interest expressed
    MUTUAL    = "mutual"     # both interested
    APPROVED  = "approved"   # wali approved
    ACTIVE    = "active"     # ongoing conversation
    NIKAH     = "nikah"      # led to nikah 🎉
    CLOSED    = "closed"     # ended respectfully
    BLOCKED   = "blocked"    # blocked by either side

class GameType(str, PyEnum):
    QALB_QUIZ        = "qalb_quiz"
    WOULD_YOU_RATHER = "would_you_rather"
    FINISH_SENTENCE  = "finish_sentence"
    VALUES_MAP       = "values_map"
    ISLAMIC_TRIVIA   = "islamic_trivia"
    QURAN_AYAH       = "quran_ayah"
    GEOGRAPHY_RACE   = "geography_race"
    HADITH_MATCH     = "hadith_match"
    BUILD_STORY      = "build_story"
    DREAM_HOME       = "dream_home"
    TIME_CAPSULE     = "time_capsule"
    HONESTY_BOX      = "honesty_box"
    PRIORITY_RANK    = "priority_rank"
    LOVE_LANGUAGES   = "love_languages"
    QUESTIONS_36     = "questions_36"
    FAMILY_TRIVIA    = "family_trivia"
    DEAL_NO_DEAL     = "deal_no_deal"

class GameStatus(str, PyEnum):
    ACTIVE    = "active"
    WAITING   = "waiting"   # waiting for other player
    COMPLETED = "completed"
    EXPIRED   = "expired"
    SEALED    = "sealed"    # time capsule — not yet revealed

class MessageStatus(str, PyEnum):
    SENT      = "sent"
    DELIVERED = "delivered"
    READ      = "read"
    FLAGGED   = "flagged"   # flagged by AI moderation

class CallType(str, PyEnum):
    AUDIO           = "audio"
    VIDEO           = "video"
    VIDEO_CHAPERONED = "video_chaperoned"  # 3-way with wali

class MadhabChoice(str, PyEnum):
    HANAFI  = "hanafi"
    MALIKI  = "maliki"
    SHAFII  = "shafii"
    HANBALI = "hanbali"
    OTHER   = "other"

class PrayerFrequency(str, PyEnum):
    ALL_FIVE    = "all_five"
    MOST        = "most"
    SOMETIMES   = "sometimes"
    FRIDAY_ONLY = "friday_only"
    WORKING_ON  = "working_on"

class HijabStance(str, PyEnum):
    WEARS          = "wears"
    OPEN_TO        = "open_to"
    FAMILY_DECIDES = "family_decides"
    PREFERENCE     = "preference"
    NA             = "na"


# ─────────────────────────────────────────────
# MIXINS
# ─────────────────────────────────────────────

class TimestampMixin:
    """Add created_at / updated_at to any model."""
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

class SoftDeleteMixin:
    """Soft delete — never hard-delete user data."""
    deleted_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        index=True,
    )

    @property
    def is_deleted(self) -> bool:
        return self.deleted_at is not None


# ─────────────────────────────────────────────
# USER
# ─────────────────────────────────────────────

class User(Base, TimestampMixin, SoftDeleteMixin):
    """
    Core user account. Minimal PII — detailed info in Profile.
    """
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        index=True,
    )

    # Auth
    email: Mapped[Optional[str]] = mapped_column(
        String(255), unique=True, nullable=True, index=True
    )
    phone: Mapped[str] = mapped_column(
        String(20), unique=True, nullable=False, index=True
    )
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)

    # Identity
    role: Mapped[UserRole] = mapped_column(
        Enum(UserRole), default=UserRole.USER, nullable=False
    )
    status: Mapped[UserStatus] = mapped_column(
        Enum(UserStatus), default=UserStatus.PENDING, nullable=False
    )
    gender: Mapped[Gender] = mapped_column(Enum(Gender), nullable=False)

    # Verification
    email_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    phone_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    id_verified: Mapped[VerificationStatus] = mapped_column(
        Enum(VerificationStatus), default=VerificationStatus.NONE
    )
    onfido_applicant_id: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)

    # Subscription
    subscription_tier: Mapped[SubscriptionTier] = mapped_column(
        Enum(SubscriptionTier), default=SubscriptionTier.BARAKAH
    )
    subscription_expires_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    stripe_customer_id: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)

    # App state
    last_seen_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    niyyah: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    onboarding_completed: Mapped[bool] = mapped_column(Boolean, default=False)
    ramadan_mode: Mapped[bool] = mapped_column(Boolean, default=False)

    # FCM push token
    fcm_token: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)

    # Relationships
    profile: Mapped[Optional["Profile"]] = relationship(
        back_populates="user", uselist=False, cascade="all, delete-orphan"
    )
    family: Mapped[Optional["Family"]] = relationship(
        back_populates="user", uselist=False, cascade="all, delete-orphan"
    )
    wali_relationship: Mapped[Optional["WaliRelationship"]] = relationship(
        "WaliRelationship",
        foreign_keys="WaliRelationship.user_id",
        back_populates="user",
        uselist=False,
    )
    sent_interests: Mapped[List["Match"]] = relationship(
        "Match", foreign_keys="Match.sender_id", back_populates="sender"
    )
    received_interests: Mapped[List["Match"]] = relationship(
        "Match", foreign_keys="Match.receiver_id", back_populates="receiver"
    )
    messages_sent: Mapped[List["Message"]] = relationship(
        "Message", foreign_keys="Message.sender_id", back_populates="sender"
    )
    notifications: Mapped[List["Notification"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )

    __table_args__ = (
        Index("ix_users_status_gender", "status", "gender"),
    )

    def __repr__(self) -> str:
        return f"<User {self.phone} [{self.role}]>"


# ─────────────────────────────────────────────
# PROFILE
# ─────────────────────────────────────────────

class Profile(Base, TimestampMixin):
    """
    Detailed Islamic profile — the heart of MiskMatch.
    """
    __tablename__ = "profiles"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"),
        unique=True, nullable=False, index=True,
    )

    # Basic info
    first_name: Mapped[str] = mapped_column(String(50), nullable=False)
    last_name: Mapped[str] = mapped_column(String(50), nullable=False)
    display_name: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    date_of_birth: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    city: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    country: Mapped[Optional[str]] = mapped_column(String(2), nullable=True)  # ISO 2-letter
    nationality: Mapped[Optional[str]] = mapped_column(String(2), nullable=True)
    languages: Mapped[Optional[list]] = mapped_column(ARRAY(String), nullable=True)

    # Biography
    bio: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    bio_ar: Mapped[Optional[str]] = mapped_column(Text, nullable=True)  # Arabic bio

    # Media
    photo_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    photos: Mapped[Optional[list]] = mapped_column(ARRAY(String), nullable=True)
    voice_intro_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    photo_visible: Mapped[bool] = mapped_column(Boolean, default=False)  # hidden until mutual

    # Islamic identity
    madhab: Mapped[Optional[MadhabChoice]] = mapped_column(
        Enum(MadhabChoice), nullable=True
    )
    prayer_frequency: Mapped[Optional[PrayerFrequency]] = mapped_column(
        Enum(PrayerFrequency), nullable=True
    )
    hijab_stance: Mapped[Optional[HijabStance]] = mapped_column(
        Enum(HijabStance), nullable=True
    )
    quran_level: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    quran_recitation_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    is_revert: Mapped[bool] = mapped_column(Boolean, default=False)
    revert_year: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    # Education & Career
    education_level: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    field_of_study: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    occupation: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    employer: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    income_range: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)

    # Life goals (Islamic)
    wants_children: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)
    num_children_desired: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    children_schooling: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    hajj_timeline: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    wants_hijra: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)
    hijra_country: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    islamic_finance_stance: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    wife_working_stance: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)

    # Personality (Sifr assessment)
    sifr_scores: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    love_language: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    priority_ranking: Mapped[Optional[list]] = mapped_column(ARRAY(String), nullable=True)

    # AI compatibility vector (embedding)
    compatibility_embedding: Mapped[Optional[list]] = mapped_column(
        ARRAY(Float), nullable=True
    )
    deen_score: Mapped[Optional[float]] = mapped_column(Float, nullable=True)

    # Search preferences
    min_age: Mapped[int] = mapped_column(Integer, default=22)
    max_age: Mapped[int] = mapped_column(Integer, default=40)
    preferred_countries: Mapped[Optional[list]] = mapped_column(ARRAY(String), nullable=True)
    max_distance_km: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    # Trust scores
    mosque_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    mosque_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True), ForeignKey("mosques.id", ondelete="SET NULL"), nullable=True
    )
    scholar_endorsed: Mapped[bool] = mapped_column(Boolean, default=False)
    trust_score: Mapped[int] = mapped_column(Integer, default=0)  # 0-100

    # Relationships
    user: Mapped["User"] = relationship(back_populates="profile")
    mosque: Mapped[Optional["Mosque"]] = relationship("Mosque")

    __table_args__ = (
        CheckConstraint("min_age >= 18 AND min_age <= 80", name="ck_profile_min_age"),
        CheckConstraint("max_age >= 18 AND max_age <= 80", name="ck_profile_max_age"),
        CheckConstraint("trust_score >= 0 AND trust_score <= 100", name="ck_profile_trust"),
        Index("ix_profiles_country_city", "country", "city"),
        Index("ix_profiles_dob", "date_of_birth"),
        Index("ix_profiles_madhab", "madhab"),
        Index("ix_profiles_prayer", "prayer_frequency"),
    )


# ─────────────────────────────────────────────
# FAMILY
# ─────────────────────────────────────────────

class Family(Base, TimestampMixin):
    """
    Family profile — Islamic marriage is a family matter.
    """
    __tablename__ = "families"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"),
        unique=True, nullable=False, index=True,
    )

    # Background
    family_origin: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    family_type: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    num_siblings: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    family_religiosity: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    father_occupation: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    mother_occupation: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)

    # Description
    family_description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    family_description_ar: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    family_values: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # Family trivia (for the game)
    family_trivia: Mapped[Optional[list]] = mapped_column(JSON, nullable=True)

    # Living arrangement after marriage
    living_arrangement: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    family_involvement: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)

    # Relationships
    user: Mapped["User"] = relationship(back_populates="family")


# ─────────────────────────────────────────────
# WALI (GUARDIAN)
# ─────────────────────────────────────────────

class WaliRelationship(Base, TimestampMixin):
    """
    Guardian relationship — the wali system.
    A wali can be a father, brother, uncle, or trusted male guardian.
    """
    __tablename__ = "wali_relationships"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"),
        unique=True, nullable=False, index=True,
    )

    # Wali details (may not be a platform user)
    wali_name: Mapped[str] = mapped_column(String(100), nullable=False)
    wali_phone: Mapped[str] = mapped_column(String(20), nullable=False)
    wali_relationship: Mapped[str] = mapped_column(String(50), nullable=False)  # father, brother, etc
    wali_user_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )  # if wali is also on the platform

    # Status
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    invitation_sent: Mapped[bool] = mapped_column(Boolean, default=False)
    invitation_accepted: Mapped[bool] = mapped_column(Boolean, default=False)
    invited_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    accepted_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    # Permissions
    can_view_matches: Mapped[bool] = mapped_column(Boolean, default=True)
    can_view_messages: Mapped[bool] = mapped_column(Boolean, default=False)  # user controls
    can_approve_matches: Mapped[bool] = mapped_column(Boolean, default=True)
    can_join_calls: Mapped[bool] = mapped_column(Boolean, default=True)

    # Relationships
    user: Mapped["User"] = relationship(
        "User", foreign_keys=[user_id], back_populates="wali_relationship"
    )
    wali_user: Mapped[Optional["User"]] = relationship(
        "User", foreign_keys=[wali_user_id]
    )


# ─────────────────────────────────────────────
# MOSQUE
# ─────────────────────────────────────────────

class Mosque(Base, TimestampMixin):
    """
    Partner mosque — verification and trust system.
    """
    __tablename__ = "mosques"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )

    name: Mapped[str] = mapped_column(String(200), nullable=False)
    name_ar: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    country: Mapped[str] = mapped_column(String(2), nullable=False)
    city: Mapped[str] = mapped_column(String(100), nullable=False)
    address: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    phone: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    email: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    website: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    imam_name: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    is_partner: Mapped[bool] = mapped_column(Boolean, default=False)
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    partner_since: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    verified_member_count: Mapped[int] = mapped_column(Integer, default=0)


# ─────────────────────────────────────────────
# MATCH
# ─────────────────────────────────────────────

class Match(Base, TimestampMixin):
    """
    Match between two users — the core connection.
    """
    __tablename__ = "matches"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )

    sender_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False, index=True,
    )
    receiver_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False, index=True,
    )

    status: Mapped[MatchStatus] = mapped_column(
        Enum(MatchStatus), default=MatchStatus.PENDING, nullable=False
    )

    # Interest expression
    sender_message: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    receiver_response: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # Wali approval
    sender_wali_approved: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)
    receiver_wali_approved: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)
    sender_wali_approved_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    receiver_wali_approved_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    # Compatibility
    compatibility_score: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    compatibility_breakdown: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)

    # Outcome
    became_mutual_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    nikah_date: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    closed_reason: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)

    # Match memory (game results, shared moments)
    match_memory: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)

    # Games engine state — all 17 games stored as JSONB per match
    # { "qalb_quiz": { status, turns, current_turn, scores, ... }, ... }
    game_states: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)

    # Timeline chronicle — milestones + completed games
    # [{ type, event, title, title_ar, icon, date, ... }, ...]
    memory_timeline: Mapped[Optional[list]] = mapped_column(JSON, nullable=True)

    # Relationships
    sender: Mapped["User"] = relationship("User", foreign_keys=[sender_id])
    receiver: Mapped["User"] = relationship("User", foreign_keys=[receiver_id])
    messages: Mapped[List["Message"]] = relationship(back_populates="match")
    games: Mapped[List["Game"]] = relationship(back_populates="match")
    calls: Mapped[List["Call"]] = relationship(back_populates="match")

    __table_args__ = (
        UniqueConstraint("sender_id", "receiver_id", name="uq_match_pair"),
        Index("ix_matches_status", "status"),
        Index("ix_matches_sender_receiver", "sender_id", "receiver_id"),
    )


# ─────────────────────────────────────────────
# MESSAGE
# ─────────────────────────────────────────────

class Message(Base, TimestampMixin):
    """
    Messages within a match — supervised, moderated.
    """
    __tablename__ = "messages"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    match_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("matches.id", ondelete="CASCADE"),
        nullable=False, index=True,
    )
    sender_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False, index=True,
    )

    content: Mapped[str] = mapped_column(Text, nullable=False)
    content_type: Mapped[str] = mapped_column(
        String(20), default="text"  # text | audio | image
    )
    media_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)

    status: Mapped[MessageStatus] = mapped_column(
        Enum(MessageStatus), default=MessageStatus.SENT
    )

    # AI moderation
    moderation_passed: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)
    moderation_reason: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)

    # Relationships
    match: Mapped["Match"] = relationship(back_populates="messages")
    sender: Mapped["User"] = relationship("User", foreign_keys=[sender_id])

    __table_args__ = (
        Index("ix_messages_match_created", "match_id", "created_at"),
    )


# ─────────────────────────────────────────────
# GAME
# ─────────────────────────────────────────────

class Game(Base, TimestampMixin):
    """
    One of the 17 match games — connection through play.
    """
    __tablename__ = "games"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    match_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("matches.id", ondelete="CASCADE"),
        nullable=False, index=True,
    )

    game_type: Mapped[GameType] = mapped_column(Enum(GameType), nullable=False)
    status: Mapped[GameStatus] = mapped_column(
        Enum(GameStatus), default=GameStatus.ACTIVE
    )

    # Game state
    current_turn_user_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    game_data: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    player1_answers: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    player2_answers: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    results: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)

    # Scores
    compatibility_delta: Mapped[Optional[float]] = mapped_column(Float, nullable=True)

    # Time capsule special fields
    sealed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    reveals_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    # Expiry
    expires_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    # Relationships
    match: Mapped["Match"] = relationship(back_populates="games")


# ─────────────────────────────────────────────
# CALL
# ─────────────────────────────────────────────

class Call(Base, TimestampMixin):
    """
    Video/audio calls — including chaperoned 3-way with wali.
    """
    __tablename__ = "calls"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    match_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("matches.id", ondelete="CASCADE"),
        nullable=False, index=True,
    )
    initiator_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )

    call_type: Mapped[CallType] = mapped_column(Enum(CallType), nullable=False)

    # Agora
    agora_channel: Mapped[str] = mapped_column(String(100), nullable=False)
    agora_token: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)

    # Participants
    wali_invited: Mapped[bool] = mapped_column(Boolean, default=False)
    wali_joined: Mapped[bool] = mapped_column(Boolean, default=False)
    wali_approved: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    # Timing
    scheduled_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    started_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    ended_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    duration_seconds: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    # Recording (with consent)
    recording_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    recording_consent: Mapped[bool] = mapped_column(Boolean, default=False)

    # Relationships
    match: Mapped["Match"] = relationship(back_populates="calls")
    initiator: Mapped["User"] = relationship("User", foreign_keys=[initiator_id])


# ─────────────────────────────────────────────
# NOTIFICATION
# ─────────────────────────────────────────────

class Notification(Base, TimestampMixin):
    """Push and in-app notifications."""
    __tablename__ = "notifications"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False, index=True,
    )

    title: Mapped[str] = mapped_column(String(200), nullable=False)
    title_ar: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    body: Mapped[str] = mapped_column(Text, nullable=False)
    body_ar: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    notification_type: Mapped[str] = mapped_column(String(50), nullable=False)
    reference_id: Mapped[Optional[uuid.UUID]] = mapped_column(UUID(as_uuid=True), nullable=True)
    reference_type: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)

    is_read: Mapped[bool] = mapped_column(Boolean, default=False)
    read_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    push_sent: Mapped[bool] = mapped_column(Boolean, default=False)

    # Relationships
    user: Mapped["User"] = relationship(back_populates="notifications")

    __table_args__ = (
        Index("ix_notifications_user_unread", "user_id", "is_read"),
    )


# ─────────────────────────────────────────────
# SUBSCRIPTION
# ─────────────────────────────────────────────

class Subscription(Base, TimestampMixin):
    """
    Subscription history — Stripe billing records.
    """
    __tablename__ = "subscriptions"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False, index=True,
    )

    tier: Mapped[SubscriptionTier] = mapped_column(Enum(SubscriptionTier), nullable=False)
    stripe_subscription_id: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    stripe_payment_intent_id: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)

    amount_cents: Mapped[int] = mapped_column(Integer, nullable=False)
    currency: Mapped[str] = mapped_column(String(3), default="USD")
    status: Mapped[str] = mapped_column(String(30), nullable=False)

    starts_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    ends_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    cancelled_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)


# ─────────────────────────────────────────────
# REPORT / BLOCK
# ─────────────────────────────────────────────

class Report(Base, TimestampMixin):
    """Safety reports and user blocks."""
    __tablename__ = "reports"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    reporter_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    reported_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )

    reason: Mapped[str] = mapped_column(String(100), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    evidence_urls: Mapped[Optional[list]] = mapped_column(ARRAY(String), nullable=True)
    is_block: Mapped[bool] = mapped_column(Boolean, default=False)

    status: Mapped[str] = mapped_column(String(30), default="pending")
    reviewed_by: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    reviewed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    resolution: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
