"""
MiskMatch — Embedding Service
AI-powered profile vectorisation for the Deen Compatibility Engine.

Architecture:
  1. Build rich Islamic profile text from structured fields + bio
  2. Embed with OpenAI text-embedding-3-small (1536 dims, $0.02/M tokens)
  3. Store vector in Profile.compatibility_embedding (ARRAY Float)
  4. At query time: cosine similarity between vectors → AI similarity score

Profile text captures:
  - Islamic practice (madhab, prayer, quran, hijab, revert)
  - Life goals (children, hajj, hijra, Islamic finance, wife working)
  - Personality (Sifr 5-dimension scores, love language, priority ranking)
  - Family context
  - Free-text bio (richest signal)

Cost: text-embedding-3-small ~ $0.000015 per profile embed
      100,000 users ≈ $1.50 total to embed the whole platform.
"""

import logging
import math
from typing import Optional

import numpy as np

from app.core.config import settings
from app.models.models import Profile

logger = logging.getLogger(__name__)

# Embedding model — best cost/quality for semantic similarity
EMBEDDING_MODEL  = "text-embedding-3-small"
EMBEDDING_DIMS   = 1536
MAX_PROFILE_CHARS = 2000   # keeps token cost predictable


# ─────────────────────────────────────────────
# PROFILE TEXT BUILDER
# ─────────────────────────────────────────────

def build_profile_text(profile: Profile) -> str:
    """
    Converts a structured Profile into a rich natural-language text
    that captures Islamic values, life goals, and personality signals
    for the embedding model.

    This text is never shown to users — it is only sent to OpenAI
    to generate the compatibility vector.
    """
    parts: list[str] = []

    # ── Islamic Practice ─────────────────────────────────────────────────────
    islamic = []

    madhab_labels = {
        "hanafi": "Hanafi", "maliki": "Maliki",
        "shafii": "Shafi'i", "hanbali": "Hanbali", "other": "follows another madhab",
    }
    if profile.madhab:
        islamic.append(f"follows the {madhab_labels.get(str(profile.madhab), str(profile.madhab))} madhab")

    prayer_labels = {
        "all_five":    "prays all five daily prayers",
        "most":        "prays most of the five daily prayers",
        "sometimes":   "prays sometimes",
        "friday_only": "prays on Fridays",
        "working_on":  "is working on establishing regular prayer",
    }
    if profile.prayer_frequency:
        islamic.append(prayer_labels.get(str(profile.prayer_frequency), str(profile.prayer_frequency)))

    quran_labels = {
        "hafiz":           "is a full Hafiz (memorised the entire Quran)",
        "hafiz_partial":   "has partially memorised the Quran",
        "memorising":      "is actively memorising the Quran",
        "recites_tajweed": "recites Quran with proper Tajweed",
        "strong":          "has strong Quran recitation",
        "learning":        "is learning Quran recitation",
        "beginner":        "is a beginner in Quran recitation",
    }
    if profile.quran_level:
        islamic.append(quran_labels.get(str(profile.quran_level), f"Quran level: {profile.quran_level}"))

    hijab_labels = {
        "wears":           "wears hijab",
        "open_to":         "is open to wearing hijab",
        "family_decides":  "will decide on hijab with family",
        "preference":      "has a preference on hijab",
        "na":              "",
    }
    hijab_text = hijab_labels.get(str(profile.hijab_stance or "na"), "")
    if hijab_text:
        islamic.append(hijab_text)

    if profile.is_revert:
        year = f" since {profile.revert_year}" if profile.revert_year else ""
        islamic.append(f"is a Muslim revert{year}")

    if islamic:
        parts.append("Islamic practice: " + "; ".join(islamic) + ".")

    # ── Life Goals ────────────────────────────────────────────────────────────
    goals = []

    if profile.wants_children is True:
        n = profile.num_children_desired or "children"
        goals.append(f"wants {n} children")
    elif profile.wants_children is False:
        goals.append("does not want children")

    if profile.children_schooling:
        goals.append(f"prefers {profile.children_schooling} schooling for children")

    hajj_labels = {
        "within_1_year":  "plans to perform Hajj within 1 year",
        "within_3_years": "plans to perform Hajj within 3 years",
        "within_5_years": "plans to perform Hajj within 5 years",
        "someday":        "plans to perform Hajj someday",
        "done":           "has already performed Hajj",
    }
    if profile.hajj_timeline:
        goals.append(hajj_labels.get(str(profile.hajj_timeline), f"Hajj: {profile.hajj_timeline}"))

    if profile.wants_hijra is True:
        dest = f" to {profile.hijra_country}" if profile.hijra_country else ""
        goals.append(f"wants to make hijra{dest}")

    finance_labels = {
        "strict":   "strictly avoids interest (riba) and uses Islamic finance only",
        "prefers":  "prefers Islamic finance and halal banking",
        "learning": "is learning about Islamic finance",
        "open":     "is open to conventional finance",
    }
    if profile.islamic_finance_stance:
        goals.append(finance_labels.get(
            str(profile.islamic_finance_stance),
            str(profile.islamic_finance_stance),
        ))

    wife_labels = {
        "yes":        "expects wife to work after marriage",
        "no":         "prefers wife to focus on home and family",
        "her_choice": "leaves the decision to the wife",
        "part_time":  "open to wife working part-time",
        "na":         "",
    }
    wife_text = wife_labels.get(str(profile.wife_working_stance or "na"), "")
    if wife_text:
        goals.append(wife_text)

    if goals:
        parts.append("Life goals: " + "; ".join(goals) + ".")

    # ── Sifr Personality Scores ───────────────────────────────────────────────
    if profile.sifr_scores and isinstance(profile.sifr_scores, dict):
        sifr = profile.sifr_scores
        dims = {
            "tawadu":   ("humility and modesty", sifr.get("tawadu", 0)),
            "sabr":     ("patience and resilience", sifr.get("sabr", 0)),
            "shukr":    ("gratitude and contentment", sifr.get("shukr", 0)),
            "rahma":    ("compassion and empathy", sifr.get("rahma", 0)),
            "amanah":   ("trustworthiness and integrity", sifr.get("amanah", 0)),
        }
        sifr_parts = []
        for key, (label, score) in dims.items():
            if score:
                level = "very high" if score >= 4.5 else "high" if score >= 3.5 else "moderate" if score >= 2.5 else "developing"
                sifr_parts.append(f"{level} {label}")
        if sifr_parts:
            parts.append(f"Personality (Sifr assessment): {'; '.join(sifr_parts)}.")

    if profile.love_language:
        love_labels = {
            "words":   "primary love language is words of affirmation",
            "acts":    "primary love language is acts of service",
            "gifts":   "primary love language is giving gifts",
            "time":    "primary love language is quality time",
            "touch":   "primary love language is appropriate physical affection",
        }
        ll = love_labels.get(str(profile.love_language), f"love language: {profile.love_language}")
        parts.append(f"Love expression: {ll}.")

    if profile.priority_ranking and isinstance(profile.priority_ranking, list):
        top3 = [str(p) for p in profile.priority_ranking[:3] if p]
        if top3:
            parts.append(f"Top life priorities: {', '.join(top3)}.")

    # ── Background ────────────────────────────────────────────────────────────
    bg = []
    if profile.city and profile.country:
        bg.append(f"based in {profile.city}, {profile.country}")
    if profile.education_level:
        bg.append(f"{profile.education_level} education")
    if profile.occupation:
        bg.append(f"works as {profile.occupation}")
    if bg:
        parts.append("Background: " + "; ".join(bg) + ".")

    # ── Bio — richest free-text signal ───────────────────────────────────────
    if profile.bio and len(profile.bio.strip()) > 10:
        bio_snippet = profile.bio.strip()[:500]
        parts.append(f"In their own words: {bio_snippet}")

    full_text = " ".join(parts)

    # Truncate to cost cap
    return full_text[:MAX_PROFILE_CHARS] if len(full_text) > MAX_PROFILE_CHARS else full_text


# ─────────────────────────────────────────────
# OPENAI EMBEDDING
# ─────────────────────────────────────────────

async def embed_text(text: str) -> Optional[list[float]]:
    """
    Call OpenAI to embed text → 1536-dimensional float vector.
    Returns None if OpenAI is not configured (dev without API key).

    Model: text-embedding-3-small
    Cost:  ~$0.02 per 1M tokens (~$0.000015 per average profile)
    """
    if not settings.OPENAI_API_KEY:
        logger.debug("Embedding skipped — OPENAI_API_KEY not set")
        return None

    try:
        from openai import AsyncOpenAI
        client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY)

        response = await client.embeddings.create(
            model=EMBEDDING_MODEL,
            input=text,
            encoding_format="float",
        )
        if not response.data:
            logger.error("OpenAI embedding returned empty data")
            return None
        vector = response.data[0].embedding
        logger.debug(f"Embedded {len(text)} chars → {len(vector)} dims")
        return vector

    except Exception as e:  # OpenAI SDK raises various APIError subclasses
        logger.error(f"OpenAI embedding failed ({type(e).__name__}): {e}")
        return None


async def embed_profile(profile: Profile) -> Optional[list[float]]:
    """Build profile text and embed it. Main entry point."""
    text = build_profile_text(profile)
    if not text.strip():
        logger.warning(f"Profile {profile.user_id} produced empty embedding text")
        return None
    return await embed_text(text)


# ─────────────────────────────────────────────
# VECTOR OPERATIONS
# ─────────────────────────────────────────────

def cosine_similarity(vec_a: list[float], vec_b: list[float]) -> float:
    """
    Cosine similarity between two embedding vectors.
    Returns a value in [-1, 1]. Higher = more semantically similar.
    For profile compatibility, typical range is [0.6, 0.95].
    """
    a = np.array(vec_a, dtype=np.float32)
    b = np.array(vec_b, dtype=np.float32)

    norm_a = np.linalg.norm(a)
    norm_b = np.linalg.norm(b)

    if norm_a == 0 or norm_b == 0:
        return 0.0

    return float(np.dot(a, b) / (norm_a * norm_b))


def similarity_to_score(similarity: float) -> float:
    """
    Convert cosine similarity [-1, 1] → compatibility score [0, 100].

    Calibrated for Islamic profile embeddings:
    - 0.85+ cosine → very high compatibility (90-100 pts)
    - 0.75-0.85   → high compatibility (75-89 pts)
    - 0.65-0.75   → moderate compatibility (55-74 pts)
    - 0.55-0.65   → low compatibility (30-54 pts)
    - <0.55       → poor compatibility (<30 pts)
    """
    # Shift from [-1,1] to [0,1]
    normalised = (similarity + 1) / 2

    # Apply sigmoid-like scaling to amplify differences in the 0.6-0.9 range
    # where most Islamic profiles will cluster
    if normalised >= 0.925:   return 95.0 + (normalised - 0.925) / 0.075 * 5
    elif normalised >= 0.875: return 85.0 + (normalised - 0.875) / 0.05  * 10
    elif normalised >= 0.825: return 72.0 + (normalised - 0.825) / 0.05  * 13
    elif normalised >= 0.775: return 57.0 + (normalised - 0.775) / 0.05  * 15
    elif normalised >= 0.725: return 40.0 + (normalised - 0.725) / 0.05  * 17
    else:                     return max(0.0, normalised / 0.725 * 40)


def euclidean_distance(vec_a: list[float], vec_b: list[float]) -> float:
    """L2 distance — alternative similarity metric."""
    a = np.array(vec_a, dtype=np.float32)
    b = np.array(vec_b, dtype=np.float32)
    return float(np.linalg.norm(a - b))


def has_embedding(profile: Profile) -> bool:
    """Check if a profile has a valid stored embedding."""
    return (
        profile.compatibility_embedding is not None
        and isinstance(profile.compatibility_embedding, list)
        and len(profile.compatibility_embedding) == EMBEDDING_DIMS
    )


# ─────────────────────────────────────────────
# FALLBACK MOCK EMBEDDING  (dev without API key)
# ─────────────────────────────────────────────

def mock_embedding_from_profile(profile: Profile) -> list[float]:
    """
    Deterministic mock embedding for development without an OpenAI key.
    Encodes key Islamic signals as structured vector components.
    NOT suitable for production — only for local testing.
    """
    vec = [0.0] * EMBEDDING_DIMS

    # Encode prayer frequency into first 5 dims
    freq_map = {
        "all_five": 1.0, "most": 0.8, "sometimes": 0.5,
        "friday_only": 0.3, "working_on": 0.2,
    }
    vec[0] = freq_map.get(str(profile.prayer_frequency or ""), 0.0)

    # Madhab as one-hot in dims 1-5
    madhab_idx = {"hanafi": 1, "maliki": 2, "shafii": 3, "hanbali": 4, "other": 5}
    idx = madhab_idx.get(str(profile.madhab or ""), 0)
    if idx:
        vec[idx] = 1.0

    # Children alignment in dim 6
    vec[6] = 1.0 if profile.wants_children else 0.0

    # Quran level in dim 7
    quran_map = {
        "hafiz": 1.0, "hafiz_partial": 0.85, "memorising": 0.7,
        "recites_tajweed": 0.6, "strong": 0.5, "learning": 0.3, "beginner": 0.2,
    }
    vec[7] = quran_map.get(str(profile.quran_level or ""), 0.0)

    # Sifr scores in dims 8-12
    if profile.sifr_scores and isinstance(profile.sifr_scores, dict):
        for i, key in enumerate(["tawadu", "sabr", "shukr", "rahma", "amanah"]):
            vec[8 + i] = float(profile.sifr_scores.get(key, 0)) / 5.0

    # Normalise to unit vector
    arr = np.array(vec, dtype=np.float32)
    norm = np.linalg.norm(arr)
    if norm > 0:
        arr = arr / norm

    return arr.tolist()
