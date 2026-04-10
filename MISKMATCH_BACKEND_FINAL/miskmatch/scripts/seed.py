#!/usr/bin/env python3
"""
MiskMatch — Seed Data Script
Populates the database with:
  - 10 partner mosques (Jordan, KSA, UK, USA, UAE, Malaysia)
  - 4 test users (2 main users + 2 walis)
  - 1 active match between Yusuf and Fatima
  - OTP for quick login in dev

Usage:
    DATABASE_URL=postgresql+asyncpg://... python scripts/seed.py
    DATABASE_URL=postgresql+asyncpg://... python scripts/seed.py --reset
"""

import asyncio
import hashlib
import os
import sys
import uuid
from datetime import datetime, timezone, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import argparse
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker

DATABASE_URL = os.environ.get(
    "DATABASE_URL",
    "postgresql+asyncpg://miskmatch:miskmatch@localhost/miskmatch"
)

engine = create_async_engine(DATABASE_URL, echo=False)
AsyncSessionLocal = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


# ─────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────

def _id() -> uuid.UUID:
    return uuid.uuid4()


def _hash(password: str) -> str:
    """Simple bcrypt-compatible hash for seed data (dev only)."""
    import bcrypt
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _ago(days=0, hours=0) -> datetime:
    return _now() - timedelta(days=days, hours=hours)


# ─────────────────────────────────────────────
# SEED DATA DEFINITIONS
# ─────────────────────────────────────────────

MOSQUES = [
    {
        "id": _id(), "name": "King Abdullah I Mosque", "name_ar": "مسجد الملك عبدالله الأول",
        "country": "JO", "city": "Amman", "address": "Al-Abdali, Amman",
        "imam_name": "Sheikh Ahmad Al-Khalidi",
        "is_partner": True, "is_verified": True, "verified_member_count": 245,
        "partner_since": _ago(days=180),
    },
    {
        "id": _id(), "name": "Al-Hussein Mosque", "name_ar": "مسجد الحسين",
        "country": "JO", "city": "Amman", "address": "Downtown Amman",
        "is_partner": True, "is_verified": True, "verified_member_count": 312,
        "partner_since": _ago(days=200),
    },
    {
        "id": _id(), "name": "Masjid Al-Haram", "name_ar": "المسجد الحرام",
        "country": "SA", "city": "Makkah",
        "is_partner": False, "is_verified": True, "verified_member_count": 0,
    },
    {
        "id": _id(), "name": "East London Mosque", "name_ar": "مسجد شرق لندن",
        "country": "GB", "city": "London", "address": "82-92 Whitechapel Rd",
        "website": "https://www.eastlondonmosque.org.uk",
        "is_partner": True, "is_verified": True, "verified_member_count": 520,
        "partner_since": _ago(days=90),
    },
    {
        "id": _id(), "name": "Islamic Society of North America Mosque",
        "name_ar": "مسجد الجمعية الإسلامية في أمريكا الشمالية",
        "country": "US", "city": "Chicago",
        "is_partner": True, "is_verified": True, "verified_member_count": 180,
        "partner_since": _ago(days=120),
    },
    {
        "id": _id(), "name": "Jumeirah Mosque", "name_ar": "مسجد جميرا",
        "country": "AE", "city": "Dubai",
        "is_partner": True, "is_verified": True, "verified_member_count": 290,
        "partner_since": _ago(days=150),
    },
    {
        "id": _id(), "name": "National Mosque of Malaysia", "name_ar": "المسجد الوطني للماليزيا",
        "country": "MY", "city": "Kuala Lumpur",
        "is_partner": True, "is_verified": True, "verified_member_count": 400,
        "partner_since": _ago(days=60),
    },
    {
        "id": _id(), "name": "Al-Noor Mosque", "name_ar": "مسجد النور",
        "country": "JO", "city": "Irbid",
        "is_partner": True, "is_verified": True, "verified_member_count": 95,
        "partner_since": _ago(days=30),
    },
    {
        "id": _id(), "name": "Birmingham Central Mosque",
        "country": "GB", "city": "Birmingham",
        "is_partner": True, "is_verified": True, "verified_member_count": 310,
        "partner_since": _ago(days=100),
    },
    {
        "id": _id(), "name": "Al-Rahma Mosque", "name_ar": "مسجد الرحمة",
        "country": "CA", "city": "Toronto",
        "is_partner": True, "is_verified": False, "verified_member_count": 0,
    },
]


def build_users_and_match(mosque_id: uuid.UUID) -> dict:
    """Build users, profiles, wali relationships, and a demo active match."""

    # ── User IDs ──────────────────────────────────────────────────────────────
    yusuf_id    = _id()
    fatima_id   = _id()
    yusuf_wali  = _id()
    fatima_wali = _id()
    match_id    = _id()

    # ── Users ─────────────────────────────────────────────────────────────────
    password_hash = _hash("Test1234!")

    users = [
        {
            "id": yusuf_id,
            "email": "yusuf@dev.miskmatch.app",
            "phone": "+962791000001",
            "password_hash": password_hash,
            "role": "USER", "status": "ACTIVE", "gender": "MALE",
            "email_verified": True, "phone_verified": True,
            "id_verified": "VERIFIED",
            "subscription_tier": "NOOR",
            "onboarding_completed": True,
            "niyyah": "I seek a spouse who will be my partner in this deen and the next.",
            "created_at": _ago(days=30), "updated_at": _ago(days=1),
        },
        {
            "id": fatima_id,
            "email": "fatima@dev.miskmatch.app",
            "phone": "+962791000002",
            "password_hash": password_hash,
            "role": "USER", "status": "ACTIVE", "gender": "FEMALE",
            "email_verified": True, "phone_verified": True,
            "id_verified": "VERIFIED",
            "subscription_tier": "NOOR",
            "onboarding_completed": True,
            "niyyah": "Looking for a righteous partner to build a home filled with barakah.",
            "created_at": _ago(days=25), "updated_at": _ago(days=1),
        },
        {
            "id": yusuf_wali,
            "email": "omar.wali@dev.miskmatch.app",
            "phone": "+962791000003",
            "password_hash": password_hash,
            "role": "WALI", "status": "ACTIVE", "gender": "MALE",
            "email_verified": True, "phone_verified": True,
            "id_verified": "NONE", "subscription_tier": "BARAKAH",
            "onboarding_completed": True,
            "created_at": _ago(days=30), "updated_at": _ago(days=5),
        },
        {
            "id": fatima_wali,
            "email": "ibrahim.wali@dev.miskmatch.app",
            "phone": "+962791000004",
            "password_hash": password_hash,
            "role": "WALI", "status": "ACTIVE", "gender": "MALE",
            "email_verified": True, "phone_verified": True,
            "id_verified": "NONE", "subscription_tier": "BARAKAH",
            "onboarding_completed": True,
            "created_at": _ago(days=25), "updated_at": _ago(days=5),
        },
    ]

    # ── Profiles ──────────────────────────────────────────────────────────────
    profiles = [
        {
            "id": _id(), "user_id": yusuf_id,
            "first_name": "Yusuf", "last_name": "Al-Rashidi",
            "display_name": "Yusuf",
            "date_of_birth": datetime(1996, 4, 12, tzinfo=timezone.utc),
            "city": "Amman", "country": "JO", "nationality": "JO",
            "languages": ["Arabic", "English"],
            "bio": "Software engineer by day, seeker of knowledge by night. Love hiking the Dead Sea trail.",
            "bio_ar": "مهندس برمجيات في النهار، طالب علم في الليل.",
            "madhab": "HANBALI", "prayer_frequency": "ALL_FIVE",
            "hijab_stance": "NA",
            "quran_level": "hafiz_partial",
            "is_revert": False,
            "education_level": "bachelors", "field_of_study": "Computer Science",
            "occupation": "Software Engineer", "employer": "Tech Company Amman",
            "wants_children": True, "num_children_desired": "3-4",
            "hajj_timeline": "within_5_years",
            "islamic_finance_stance": "strict",
            "wife_working_stance": "her_choice",
            "mosque_verified": True, "mosque_id": mosque_id,
            "trust_score": 82,
            "min_age": 22, "max_age": 35,
            "preferred_countries": ["JO", "SA", "AE", "GB"],
            "photo_visible": False,
            "created_at": _ago(days=29), "updated_at": _ago(days=1),
        },
        {
            "id": _id(), "user_id": fatima_id,
            "first_name": "Fatima", "last_name": "Al-Zahra",
            "display_name": "Fatima",
            "date_of_birth": datetime(1998, 8, 25, tzinfo=timezone.utc),
            "city": "Amman", "country": "JO", "nationality": "JO",
            "languages": ["Arabic", "English", "French"],
            "bio": "Medical student and Quran teacher. Passionate about Islamic psychology and family wellbeing.",
            "bio_ar": "طالبة طب ومعلمة قرآن. شغوفة بعلم النفس الإسلامي.",
            "madhab": "SHAFII", "prayer_frequency": "ALL_FIVE",
            "hijab_stance": "WEARS",
            "quran_level": "recites_tajweed",
            "is_revert": False,
            "education_level": "masters", "field_of_study": "Medicine",
            "occupation": "Medical Student",
            "wants_children": True, "num_children_desired": "2-3",
            "hajj_timeline": "within_3_years",
            "islamic_finance_stance": "prefers",
            "wife_working_stance": "na",
            "mosque_verified": True, "mosque_id": mosque_id,
            "trust_score": 91,
            "min_age": 25, "max_age": 38,
            "preferred_countries": ["JO", "SA", "GB"],
            "photo_visible": False,
            "created_at": _ago(days=24), "updated_at": _ago(days=1),
        },
    ]

    # ── Families ──────────────────────────────────────────────────────────────
    families = [
        {
            "id": _id(), "user_id": yusuf_id,
            "family_origin": "Irbid, Jordan",
            "family_type": "nuclear",
            "num_siblings": 2,
            "family_religiosity": "practicing",
            "father_occupation": "Teacher",
            "mother_occupation": "Homemaker",
            "family_description": "A close-knit family from Irbid, Jordan. We gather every Friday for family dinner.",
            "living_arrangement": "nuclear_preferred",
            "created_at": _ago(days=28), "updated_at": _ago(days=2),
        },
        {
            "id": _id(), "user_id": fatima_id,
            "family_origin": "Amman, Jordan",
            "family_type": "extended",
            "num_siblings": 4,
            "family_religiosity": "very_practicing",
            "father_occupation": "Doctor",
            "mother_occupation": "Teacher",
            "family_description": "A large, warm Amman family. Education and deen are central to everything we do.",
            "living_arrangement": "flexible",
            "created_at": _ago(days=23), "updated_at": _ago(days=2),
        },
    ]

    # ── Wali Relationships ────────────────────────────────────────────────────
    wali_relationships = [
        {
            "id": _id(), "user_id": yusuf_id,
            "wali_name": "Omar Al-Rashidi",
            "wali_phone": "+962791000003",
            "wali_relationship": "father",
            "wali_user_id": yusuf_wali,
            "is_active": True, "invitation_sent": True, "invitation_accepted": True,
            "invited_at": _ago(days=29), "accepted_at": _ago(days=28),
            "can_view_matches": True, "can_view_messages": False,
            "can_approve_matches": True, "can_join_calls": True,
            "created_at": _ago(days=29), "updated_at": _ago(days=28),
        },
        {
            "id": _id(), "user_id": fatima_id,
            "wali_name": "Ibrahim Al-Zahra",
            "wali_phone": "+962791000004",
            "wali_relationship": "father",
            "wali_user_id": fatima_wali,
            "is_active": True, "invitation_sent": True, "invitation_accepted": True,
            "invited_at": _ago(days=24), "accepted_at": _ago(days=23),
            "can_view_matches": True, "can_view_messages": False,
            "can_approve_matches": True, "can_join_calls": True,
            "created_at": _ago(days=24), "updated_at": _ago(days=23),
        },
    ]

    # ── Match (ACTIVE — wali approved) ────────────────────────────────────────
    became_mutual = _ago(days=10)
    matches = [
        {
            "id": match_id,
            "sender_id": yusuf_id,
            "receiver_id": fatima_id,
            "status": "ACTIVE",
            "sender_message": "Assalamu Alaikum. I was moved by your profile and your commitment to your deen. I would be honoured to get to know you with good intentions.",
            "receiver_response": "Wa Alaikum Assalam. JazakAllah Khair for your kind words. I am open to proceeding with the blessing of my wali.",
            "sender_wali_approved": True,
            "receiver_wali_approved": True,
            "sender_wali_approved_at": _ago(days=9),
            "receiver_wali_approved_at": _ago(days=8),
            "compatibility_score": 87.4,
            "compatibility_breakdown": {
                "deen": 35.0, "life_goals": 28.5,
                "personality": 15.9, "practical": 8.0,
            },
            "became_mutual_at": became_mutual,
            "game_states": {},
            "memory_timeline": [
                {
                    "type": "milestone", "event": "match_started",
                    "title": "Your journey began", "title_ar": "بدأت رحلتكما",
                    "icon": "🌱",
                    "date": became_mutual.isoformat(),
                },
                {
                    "type": "milestone", "event": "wali_approved",
                    "title": "Both families gave their blessing",
                    "title_ar": "باركت الأسرتان",
                    "icon": "🤲",
                    "date": _ago(days=8).isoformat(),
                },
            ],
            "created_at": _ago(days=12), "updated_at": _ago(hours=1),
        }
    ]

    # ── Seed messages ─────────────────────────────────────────────────────────
    messages = [
        {
            "id": _id(), "match_id": match_id, "sender_id": yusuf_id,
            "content": "Assalamu Alaikum! Alhamdulillah that our families have given their blessing. I look forward to getting to know you through this platform with the proper boundaries in sha Allah.",
            "content_type": "text", "status": "READ",
            "moderation_passed": True,
            "created_at": _ago(days=8, hours=2), "updated_at": _ago(days=8, hours=2),
        },
        {
            "id": _id(), "match_id": match_id, "sender_id": fatima_id,
            "content": "Wa Alaikum Assalam! JazakAllah Khair, and Alhamdulillah. May Allah put barakah in this process for both of us. I'm happy to start with the games - I've heard the Qalb Quiz is quite insightful!",
            "content_type": "text", "status": "READ",
            "moderation_passed": True,
            "created_at": _ago(days=8, hours=1), "updated_at": _ago(days=8, hours=1),
        },
        {
            "id": _id(), "match_id": match_id, "sender_id": yusuf_id,
            "content": "Yes! I thought it would be a wonderful way to understand each other's values deeply. Shall we start with the Qalb Quiz today?",
            "content_type": "text", "status": "DELIVERED",
            "moderation_passed": True,
            "created_at": _ago(hours=3), "updated_at": _ago(hours=3),
        },
    ]

    # ── Notifications ─────────────────────────────────────────────────────────
    notifications = [
        {
            "id": _id(), "user_id": yusuf_id,
            "title": "🤲 Both walis have approved!",
            "title_ar": "🤲 وافق كلا الوليّين!",
            "body": "MashaAllah! Both families have given their blessing. Your match is now active. Begin your journey with bismillah.",
            "body_ar": "ما شاء الله! وافقت كلتا العائلتين. ابدأ رحلتكما بسم الله.",
            "notification_type": "wali_approved",
            "reference_id": match_id, "reference_type": "match",
            "is_read": True,
            "created_at": _ago(days=8), "updated_at": _ago(days=8),
        },
        {
            "id": _id(), "user_id": fatima_id,
            "title": "🤲 Both walis have approved!",
            "title_ar": "🤲 وافق كلا الوليّين!",
            "body": "MashaAllah! Both families have given their blessing. Your match is now active. Begin your journey with bismillah.",
            "body_ar": "ما شاء الله! وافقت كلتا العائلتين. ابدأ رحلتكما بسم الله.",
            "notification_type": "wali_approved",
            "reference_id": match_id, "reference_type": "match",
            "is_read": True,
            "created_at": _ago(days=8), "updated_at": _ago(days=8),
        },
        {
            "id": _id(), "user_id": yusuf_id,
            "title": "New message from Fatima",
            "title_ar": "رسالة جديدة من فاطمة",
            "body": "Wa Alaikum Assalam! JazakAllah Khair...",
            "notification_type": "new_message",
            "reference_id": match_id, "reference_type": "match",
            "is_read": False,
            "created_at": _ago(hours=3), "updated_at": _ago(hours=3),
        },
    ]

    return {
        "users": users,
        "profiles": profiles,
        "families": families,
        "wali_relationships": wali_relationships,
        "matches": matches,
        "messages": messages,
        "notifications": notifications,
        "ids": {
            "yusuf_id": yusuf_id,
            "fatima_id": fatima_id,
            "yusuf_wali_id": yusuf_wali,
            "fatima_wali_id": fatima_wali,
            "match_id": match_id,
        },
    }


# ─────────────────────────────────────────────
# MAIN SEED RUNNER
# ─────────────────────────────────────────────

async def seed(reset: bool = False) -> None:
    from sqlalchemy import text

    async with AsyncSessionLocal() as db:
        if reset:
            print("⚠️  Resetting database...")
            for table in [
                "notifications", "messages", "games", "calls", "matches",
                "wali_relationships", "families", "profiles",
                "reports", "subscriptions", "users", "mosques",
            ]:
                await db.execute(text(f"TRUNCATE TABLE {table} RESTART IDENTITY CASCADE"))
            await db.commit()
            print("✓ Tables truncated")

        # ── Mosques ───────────────────────────────────────────────────────────
        print("Seeding mosques...")
        from sqlalchemy import insert
        await db.execute(
            text("""
                INSERT INTO mosques (
                    id, name, name_ar, country, city, address, imam_name,
                    is_partner, is_verified, verified_member_count, partner_since,
                    created_at, updated_at
                ) VALUES (
                    :id, :name, :name_ar, :country, :city, :address, :imam_name,
                    :is_partner, :is_verified, :verified_member_count, :partner_since,
                    now(), now()
                ) ON CONFLICT DO NOTHING
            """),
            [
                {
                    "id": str(m["id"]),
                    "name": m["name"],
                    "name_ar": m.get("name_ar"),
                    "country": m["country"],
                    "city": m["city"],
                    "address": m.get("address"),
                    "imam_name": m.get("imam_name"),
                    "is_partner": m["is_partner"],
                    "is_verified": m["is_verified"],
                    "verified_member_count": m.get("verified_member_count", 0),
                    "partner_since": m.get("partner_since"),
                }
                for m in MOSQUES
            ]
        )
        await db.commit()
        print(f"  ✓ {len(MOSQUES)} mosques seeded")

        # Build users + match data using first mosque ID
        mosque_id = MOSQUES[0]["id"]
        data = build_users_and_match(mosque_id)

        # ── Users ─────────────────────────────────────────────────────────────
        print("Seeding users...")
        for u in data["users"]:
            await db.execute(text("""
                INSERT INTO users (
                    id, email, phone, password_hash, role, status, gender,
                    email_verified, phone_verified, id_verified,
                    subscription_tier, onboarding_completed,
                    ramadan_mode, niyyah, created_at, updated_at
                ) VALUES (
                    :id, :email, :phone, :password_hash, CAST(:role AS userrole), CAST(:status AS userstatus),
                    CAST(:gender AS gender), :email_verified, :phone_verified, CAST(:id_verified AS verificationstatus),
                    CAST(:subscription_tier AS subscriptiontier), :onboarding_completed,
                    :ramadan_mode, :niyyah, :created_at, :updated_at
                ) ON CONFLICT DO NOTHING
            """), {
                "id": str(u["id"]), "email": u["email"], "phone": u["phone"],
                "password_hash": u["password_hash"], "role": u["role"],
                "status": u["status"], "gender": u["gender"],
                "email_verified": u["email_verified"], "phone_verified": u["phone_verified"],
                "id_verified": u["id_verified"],
                "subscription_tier": u["subscription_tier"],
                "onboarding_completed": u["onboarding_completed"],
                "ramadan_mode": False,
                "niyyah": u.get("niyyah"), "created_at": u["created_at"],
                "updated_at": u["updated_at"],
            })
        await db.commit()
        print(f"  ✓ {len(data['users'])} users seeded")

        # ── Profiles ──────────────────────────────────────────────────────────
        print("Seeding profiles...")
        for p in data["profiles"]:
            await db.execute(text("""
                INSERT INTO profiles (
                    id, user_id, first_name, last_name, display_name, date_of_birth,
                    city, country, nationality, languages, bio, bio_ar,
                    madhab, prayer_frequency, hijab_stance, quran_level,
                    is_revert, education_level, field_of_study, occupation,
                    wants_children, num_children_desired, hajj_timeline,
                    islamic_finance_stance, wife_working_stance,
                    mosque_verified, mosque_id, scholar_endorsed, trust_score,
                    min_age, max_age, preferred_countries, photo_visible,
                    created_at, updated_at
                ) VALUES (
                    :id, :user_id, :first_name, :last_name, :display_name, :date_of_birth,
                    :city, :country, :nationality, :languages, :bio, :bio_ar,
                    CAST(:madhab AS madhabchoice), CAST(:prayer_frequency AS prayerfrequency), CAST(:hijab_stance AS hijabstance),
                    :quran_level, :is_revert, :education_level, :field_of_study, :occupation,
                    :wants_children, :num_children_desired, :hajj_timeline,
                    :islamic_finance_stance, :wife_working_stance,
                    :mosque_verified, :mosque_id, :scholar_endorsed, :trust_score,
                    :min_age, :max_age, :preferred_countries, :photo_visible,
                    :created_at, :updated_at
                ) ON CONFLICT DO NOTHING
            """), {
                "id": str(p["id"]), "user_id": str(p["user_id"]),
                "first_name": p["first_name"], "last_name": p["last_name"],
                "display_name": p.get("display_name"),
                "date_of_birth": p.get("date_of_birth"),
                "city": p.get("city"), "country": p.get("country"),
                "nationality": p.get("nationality"),
                "languages": p.get("languages"),
                "bio": p.get("bio"), "bio_ar": p.get("bio_ar"),
                "madhab": p.get("madhab"), "prayer_frequency": p.get("prayer_frequency"),
                "hijab_stance": p.get("hijab_stance"), "quran_level": p.get("quran_level"),
                "is_revert": p.get("is_revert", False),
                "education_level": p.get("education_level"),
                "field_of_study": p.get("field_of_study"),
                "occupation": p.get("occupation"),
                "wants_children": p.get("wants_children"),
                "num_children_desired": p.get("num_children_desired"),
                "hajj_timeline": p.get("hajj_timeline"),
                "islamic_finance_stance": p.get("islamic_finance_stance"),
                "wife_working_stance": p.get("wife_working_stance"),
                "mosque_verified": p.get("mosque_verified", False),
                "mosque_id": str(p["mosque_id"]) if p.get("mosque_id") else None,
                "scholar_endorsed": False,
                "trust_score": p.get("trust_score", 0),
                "min_age": p.get("min_age", 22), "max_age": p.get("max_age", 40),
                "preferred_countries": p.get("preferred_countries"),
                "photo_visible": p.get("photo_visible", False),
                "created_at": p["created_at"], "updated_at": p["updated_at"],
            })
        await db.commit()
        print(f"  ✓ {len(data['profiles'])} profiles seeded")

        # ── Families ──────────────────────────────────────────────────────────
        print("Seeding families...")
        for f in data["families"]:
            await db.execute(text("""
                INSERT INTO families (
                    id, user_id, family_origin, family_type, num_siblings,
                    family_religiosity, father_occupation, mother_occupation,
                    family_description, living_arrangement, created_at, updated_at
                ) VALUES (
                    :id, :user_id, :family_origin, :family_type, :num_siblings,
                    :family_religiosity, :father_occupation, :mother_occupation,
                    :family_description, :living_arrangement, :created_at, :updated_at
                ) ON CONFLICT DO NOTHING
            """), {
                "id": str(f["id"]), "user_id": str(f["user_id"]),
                "family_origin": f.get("family_origin"), "family_type": f.get("family_type"),
                "num_siblings": f.get("num_siblings"),
                "family_religiosity": f.get("family_religiosity"),
                "father_occupation": f.get("father_occupation"),
                "mother_occupation": f.get("mother_occupation"),
                "family_description": f.get("family_description"),
                "living_arrangement": f.get("living_arrangement"),
                "created_at": f["created_at"], "updated_at": f["updated_at"],
            })
        await db.commit()
        print(f"  ✓ {len(data['families'])} families seeded")

        # ── Wali Relationships ────────────────────────────────────────────────
        print("Seeding wali relationships...")
        for w in data["wali_relationships"]:
            await db.execute(text("""
                INSERT INTO wali_relationships (
                    id, user_id, wali_name, wali_phone, wali_relationship, wali_user_id,
                    is_active, invitation_sent, invitation_accepted, invited_at, accepted_at,
                    can_view_matches, can_view_messages, can_approve_matches, can_join_calls,
                    created_at, updated_at
                ) VALUES (
                    :id, :user_id, :wali_name, :wali_phone, :wali_relationship, :wali_user_id,
                    :is_active, :invitation_sent, :invitation_accepted, :invited_at, :accepted_at,
                    :can_view_matches, :can_view_messages, :can_approve_matches, :can_join_calls,
                    :created_at, :updated_at
                ) ON CONFLICT DO NOTHING
            """), {
                "id": str(w["id"]), "user_id": str(w["user_id"]),
                "wali_name": w["wali_name"], "wali_phone": w["wali_phone"],
                "wali_relationship": w["wali_relationship"],
                "wali_user_id": str(w["wali_user_id"]) if w.get("wali_user_id") else None,
                "is_active": w["is_active"], "invitation_sent": w["invitation_sent"],
                "invitation_accepted": w["invitation_accepted"],
                "invited_at": w.get("invited_at"), "accepted_at": w.get("accepted_at"),
                "can_view_matches": w["can_view_matches"],
                "can_view_messages": w["can_view_messages"],
                "can_approve_matches": w["can_approve_matches"],
                "can_join_calls": w["can_join_calls"],
                "created_at": w["created_at"], "updated_at": w["updated_at"],
            })
        await db.commit()
        print(f"  ✓ {len(data['wali_relationships'])} wali relationships seeded")

        # ── Match ─────────────────────────────────────────────────────────────
        print("Seeding match...")
        import json
        m = data["matches"][0]
        await db.execute(text("""
            INSERT INTO matches (
                id, sender_id, receiver_id, status,
                sender_message, receiver_response,
                sender_wali_approved, receiver_wali_approved,
                sender_wali_approved_at, receiver_wali_approved_at,
                compatibility_score, compatibility_breakdown,
                became_mutual_at, game_states, memory_timeline,
                created_at, updated_at
            ) VALUES (
                :id, :sender_id, :receiver_id, CAST(:status AS matchstatus),
                :sender_message, :receiver_response,
                :sender_wali_approved, :receiver_wali_approved,
                :sender_wali_approved_at, :receiver_wali_approved_at,
                :compatibility_score, CAST(:compatibility_breakdown AS json),
                :became_mutual_at, CAST(:game_states AS json), CAST(:memory_timeline AS json),
                :created_at, :updated_at
            ) ON CONFLICT DO NOTHING
        """), {
            "id": str(m["id"]), "sender_id": str(m["sender_id"]),
            "receiver_id": str(m["receiver_id"]), "status": m["status"],
            "sender_message": m.get("sender_message"),
            "receiver_response": m.get("receiver_response"),
            "sender_wali_approved": m.get("sender_wali_approved"),
            "receiver_wali_approved": m.get("receiver_wali_approved"),
            "sender_wali_approved_at": m.get("sender_wali_approved_at"),
            "receiver_wali_approved_at": m.get("receiver_wali_approved_at"),
            "compatibility_score": m.get("compatibility_score"),
            "compatibility_breakdown": json.dumps(m.get("compatibility_breakdown")),
            "became_mutual_at": m.get("became_mutual_at"),
            "game_states": json.dumps(m.get("game_states", {})),
            "memory_timeline": json.dumps(m.get("memory_timeline", [])),
            "created_at": m["created_at"], "updated_at": m["updated_at"],
        })
        await db.commit()
        print("  ✓ 1 active match seeded (Yusuf ↔ Fatima, day 10)")

        # ── Messages ──────────────────────────────────────────────────────────
        print("Seeding messages...")
        for msg in data["messages"]:
            await db.execute(text("""
                INSERT INTO messages (
                    id, match_id, sender_id, content, content_type, status,
                    moderation_passed, created_at, updated_at
                ) VALUES (
                    :id, :match_id, :sender_id, :content, :content_type, CAST(:status AS messagestatus),
                    :moderation_passed, :created_at, :updated_at
                ) ON CONFLICT DO NOTHING
            """), {
                "id": str(msg["id"]), "match_id": str(msg["match_id"]),
                "sender_id": str(msg["sender_id"]), "content": msg["content"],
                "content_type": msg["content_type"], "status": msg["status"],
                "moderation_passed": msg.get("moderation_passed"),
                "created_at": msg["created_at"], "updated_at": msg["updated_at"],
            })
        await db.commit()
        print(f"  ✓ {len(data['messages'])} seed messages seeded")

        # ── Notifications ─────────────────────────────────────────────────────
        print("Seeding notifications...")
        for n in data["notifications"]:
            await db.execute(text("""
                INSERT INTO notifications (
                    id, user_id, title, title_ar, body, body_ar,
                    notification_type, reference_id, reference_type,
                    is_read, push_sent, created_at, updated_at
                ) VALUES (
                    :id, :user_id, :title, :title_ar, :body, :body_ar,
                    :notification_type, :reference_id, :reference_type,
                    :is_read, :push_sent, :created_at, :updated_at
                ) ON CONFLICT DO NOTHING
            """), {
                "id": str(n["id"]), "user_id": str(n["user_id"]),
                "title": n["title"], "title_ar": n.get("title_ar"),
                "body": n["body"], "body_ar": n.get("body_ar"),
                "notification_type": n["notification_type"],
                "reference_id": str(n["reference_id"]) if n.get("reference_id") else None,
                "reference_type": n.get("reference_type"),
                "is_read": n.get("is_read", False),
                "push_sent": False,
                "created_at": n["created_at"], "updated_at": n["updated_at"],
            })
        await db.commit()
        print(f"  ✓ {len(data['notifications'])} notifications seeded")

    # ── Summary ───────────────────────────────────────────────────────────────
    ids = data["ids"]
    print()
    print("=" * 55)
    print("  MiskMatch seed complete — Bismillah 🌙")
    print("=" * 55)
    print()
    print("  Test credentials (all passwords: Test1234!)")
    print(f"  Yusuf (groom)  : yusuf@dev.miskmatch.app")
    print(f"  Fatima (bride) : fatima@dev.miskmatch.app")
    print(f"  Omar (wali ♂)  : omar.wali@dev.miskmatch.app")
    print(f"  Ibrahim (wali) : ibrahim.wali@dev.miskmatch.app")
    print()
    print(f"  Match ID  : {ids['match_id']}")
    print(f"  Match day : 10  (day-1 games unlocked ✓)")
    print(f"  Status    : ACTIVE — both walis approved 🤲")
    print()
    print("  Mosques   : 10 partner mosques loaded")
    print("  Messages  : 3 seed messages in match")
    print("=" * 55)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--reset", action="store_true", help="Truncate tables before seeding")
    args = parser.parse_args()
    asyncio.run(seed(reset=args.reset))
