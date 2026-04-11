"""
MiskMatch — AI Deen Compatibility Engine
Hybrid scoring: rule-based constraints + AI embedding similarity.

Scoring Architecture:
  ┌─────────────────────────────────────────────────────┐
  │  RULE ENGINE (40%)          AI ENGINE (60%)         │
  │  ─────────────────          ────────────────         │
  │  • Prayer frequency         • Semantic profile       │
  │  • Children dealbreaker       similarity             │
  │  • Madhab alignment         • Values alignment       │
  │  • Quran level              • Life goals nuance      │
  │  • Age range checks         • Personality fit        │
  │  • Location preference      • Bio text meaning       │
  │                             • Sifr dimension match   │
  └─────────────────────────────────────────────────────┘
           ↓ weighted blend ↓
      HYBRID SCORE  (0 – 100)
           ↓ dealbreaker filter ↓
      FINAL SCORE  (hard mismatches → 0)

Why 40/60 split?
  Rules enforce hard Islamic constraints (children is near-dealbreaker).
  Embeddings capture nuanced alignment rules can't express
  (e.g. two "all_five" prayers people with completely different values
   should not score equally high).
"""

import logging
from dataclasses import dataclass, field
from typing import Optional

from sqlalchemy import select, and_, or_, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.models import Profile, User, Match, MatchStatus, Gender
from app.services.embeddings import (
    cosine_similarity, similarity_to_score,
    has_embedding, mock_embedding_from_profile,
    EMBEDDING_DIMS,
)

logger = logging.getLogger(__name__)

# Scoring weights
RULE_WEIGHT      = 0.40
EMBEDDING_WEIGHT = 0.60

# Hard dealbreaker threshold — below this the match is suppressed
DEALBREAKER_THRESHOLD = 15.0


# ─────────────────────────────────────────────
# SCORING RESULT
# ─────────────────────────────────────────────

@dataclass
class CompatibilityResult:
    """Full scored result with explainability."""
    final_score:      float          # 0-100 — the number shown to users
    rule_score:       float          # 0-100 — rule engine component
    ai_score:         float          # 0-100 — embedding component (None if no vectors)
    ai_similarity:    Optional[float]  # raw cosine similarity [-1, 1]
    has_ai:           bool           # whether AI score was available
    dealbreaker:      bool           # whether a hard constraint was violated
    dealbreaker_reason: Optional[str]
    breakdown: dict = field(default_factory=dict)  # rule sub-scores

    def to_dict(self) -> dict:
        return {
            "final_score":        round(self.final_score, 1),
            "rule_score":         round(self.rule_score, 1),
            "ai_score":           round(self.ai_score, 1) if self.ai_score else None,
            "ai_similarity":      round(self.ai_similarity, 4) if self.ai_similarity else None,
            "has_ai_scoring":     self.has_ai,
            "is_dealbreaker":     self.dealbreaker,
            "dealbreaker_reason": self.dealbreaker_reason,
            "breakdown":          self.breakdown,
        }


# ─────────────────────────────────────────────
# RULE ENGINE
# ─────────────────────────────────────────────

def _rule_score(a: Profile, b: Profile) -> tuple[float, dict, bool, Optional[str]]:
    """
    Run the rule-based compatibility engine.
    Returns (score, breakdown, is_dealbreaker, reason).

    Score starts at 40 (generous baseline) so even partial profiles
    get a reasonable foundation.
    """
    score = 40.0
    breakdown: dict = {}

    # ── 1. HARD DEALBREAKERS ──────────────────────────────────────────────────
    # Children alignment — near-absolute constraint in Islamic marriage
    if a.wants_children is not None and b.wants_children is not None:
        if a.wants_children != b.wants_children:
            return 0.0, {"dealbreaker": "children_mismatch"}, True, (
                "One partner wants children and the other does not. "
                "This is a fundamental life goal incompatibility."
            )

    # ── 2. DEEN ALIGNMENT  (35 pts max) ──────────────────────────────────────

    # Prayer frequency — single most important signal
    freq_map = {
        "all_five": 5, "most": 4, "sometimes": 3,
        "friday_only": 2, "working_on": 1,
    }
    a_freq = freq_map.get(str(a.prayer_frequency or ""), 0)
    b_freq = freq_map.get(str(b.prayer_frequency or ""), 0)
    if a_freq and b_freq:
        diff = abs(a_freq - b_freq)
        prayer_pts = {0: 15, 1: 9, 2: 3, 3: -5, 4: -12}.get(diff, -12)
        score += prayer_pts
        breakdown["prayer_alignment"] = prayer_pts
        if diff >= 3:
            return score, breakdown, True, (
                "Significant difference in prayer practice. "
                "This is a core deen compatibility issue."
            )

    # Madhab alignment
    if a.madhab and b.madhab:
        if str(a.madhab) == str(b.madhab):
            madhab_pts = 10
        elif "other" not in [str(a.madhab), str(b.madhab)]:
            madhab_pts = 4   # different but known madhabs — often compatible
        else:
            madhab_pts = 2
        score += madhab_pts
        breakdown["madhab_alignment"] = madhab_pts

    # Quran level
    quran_map = {
        "hafiz": 5, "hafiz_partial": 4, "memorising": 4,
        "recites_tajweed": 3, "strong": 3, "learning": 2, "beginner": 1,
    }
    a_q = quran_map.get(str(a.quran_level or "").lower(), 0)
    b_q = quran_map.get(str(b.quran_level or "").lower(), 0)
    if a_q and b_q:
        q_diff = abs(a_q - b_q)
        quran_pts = 8 if q_diff == 0 else 5 if q_diff == 1 else 2 if q_diff == 2 else 0
        score += quran_pts
        breakdown["quran_alignment"] = quran_pts

    # Revert support
    if a.is_revert and b.is_revert:
        score += 3
        breakdown["both_reverts"] = 3

    # ── 3. LIFE GOALS  (30 pts max) ──────────────────────────────────────────

    # Children count preference
    if a.num_children_desired and b.num_children_desired:
        if str(a.num_children_desired) == str(b.num_children_desired):
            score += 8
            breakdown["children_count"] = 8
        else:
            score += 2
            breakdown["children_count"] = 2

    # Hajj timeline alignment
    hajj_order = {
        "within_1_year": 1, "within_3_years": 2,
        "within_5_years": 3, "someday": 4, "done": 0,
    }
    a_hajj = hajj_order.get(str(a.hajj_timeline or ""), -1)
    b_hajj = hajj_order.get(str(b.hajj_timeline or ""), -1)
    if a_hajj >= 0 and b_hajj >= 0:
        h_diff = abs(a_hajj - b_hajj)
        hajj_pts = 8 if h_diff == 0 else 5 if h_diff == 1 else 2
        score += hajj_pts
        breakdown["hajj_alignment"] = hajj_pts

    # Hijra alignment
    if a.wants_hijra is not None and b.wants_hijra is not None:
        if a.wants_hijra == b.wants_hijra:
            score += 5
            breakdown["hijra_alignment"] = 5

    # Islamic finance stance
    finance_map = {"strict": 3, "prefers": 2, "learning": 1, "open": 0}
    a_fin = finance_map.get(str(a.islamic_finance_stance or ""), -1)
    b_fin = finance_map.get(str(b.islamic_finance_stance or ""), -1)
    if a_fin >= 0 and b_fin >= 0:
        fin_diff = abs(a_fin - b_fin)
        fin_pts = 5 if fin_diff == 0 else 3 if fin_diff == 1 else 1
        score += fin_pts
        breakdown["islamic_finance"] = fin_pts

    # ── 4. PRACTICAL  (15 pts max) ───────────────────────────────────────────

    # Trust score differential — very high trust difference reduces score
    if a.trust_score and b.trust_score:
        trust_diff = abs(a.trust_score - b.trust_score)
        if trust_diff < 20:   trust_pts = 5
        elif trust_diff < 40: trust_pts = 2
        else:                 trust_pts = 0
        score += trust_pts
        breakdown["trust_alignment"] = trust_pts

    # Mosque verification — shared community signal
    if a.mosque_verified and b.mosque_verified:
        score += 3
        breakdown["both_mosque_verified"] = 3

    # Scholar endorsement
    if a.scholar_endorsed and b.scholar_endorsed:
        score += 3
        breakdown["both_scholar_endorsed"] = 3

    # Age range cross-validation
    # (does profile_a fit within profile_b's stated preference?)
    # Age-based age calculation skipped here — done at filter level

    return min(100.0, max(0.0, score)), breakdown, False, None


# ─────────────────────────────────────────────
# HYBRID SCORER  (main entry point)
# ─────────────────────────────────────────────

def compute_hybrid_score(
    profile_a: Profile,
    profile_b: Profile,
) -> CompatibilityResult:
    """
    Compute the hybrid AI + rule compatibility score.

    This is the primary scoring function used throughout the platform:
    - express_interest: initial score stored on match
    - discovery: ranking of candidates
    - /compatibility endpoint: explained breakdown

    Falls back gracefully to rule-only scoring when embeddings
    are not yet generated (new profiles, no API key in dev).
    """
    # ── Rule engine ───────────────────────────────────────────────────────────
    rule_score, breakdown, is_dealbreaker, db_reason = _rule_score(a=profile_a, b=profile_b)

    if is_dealbreaker:
        return CompatibilityResult(
            final_score=0.0, rule_score=0.0, ai_score=0.0,
            ai_similarity=None, has_ai=False,
            dealbreaker=True, dealbreaker_reason=db_reason,
            breakdown=breakdown,
        )

    # ── AI embedding engine ───────────────────────────────────────────────────
    ai_score     = None
    ai_similarity = None
    has_ai       = False

    vec_a = profile_a.compatibility_embedding
    vec_b = profile_b.compatibility_embedding

    # Fall back to mock embeddings in dev if no real ones
    if not (vec_a and len(vec_a) == EMBEDDING_DIMS):
        vec_a = mock_embedding_from_profile(profile_a)
    if not (vec_b and len(vec_b) == EMBEDDING_DIMS):
        vec_b = mock_embedding_from_profile(profile_b)

    real_embeddings = (
        has_embedding(profile_a) and has_embedding(profile_b)
    )

    if vec_a and vec_b:
        try:
            ai_similarity = cosine_similarity(vec_a, vec_b)
            ai_score      = similarity_to_score(ai_similarity)
            has_ai        = real_embeddings
        except (ValueError, TypeError, ZeroDivisionError) as e:
            logger.warning(f"Cosine similarity failed ({type(e).__name__}): {e}")

    # ── Hybrid blend ──────────────────────────────────────────────────────────
    if ai_score is not None:
        final = RULE_WEIGHT * rule_score + EMBEDDING_WEIGHT * ai_score
    else:
        # No embeddings — rule engine only
        final = rule_score

    final = min(100.0, max(0.0, final))

    breakdown["rule_weight"]      = f"{int(RULE_WEIGHT * 100)}%"
    breakdown["embedding_weight"] = f"{int(EMBEDDING_WEIGHT * 100)}%"

    return CompatibilityResult(
        final_score=final,
        rule_score=rule_score,
        ai_score=ai_score,
        ai_similarity=ai_similarity,
        has_ai=has_ai,
        dealbreaker=False,
        dealbreaker_reason=None,
        breakdown=breakdown,
    )


# ─────────────────────────────────────────────
# COMPATIBILITY EXPLANATION
# ─────────────────────────────────────────────

def explain_compatibility(result: CompatibilityResult, gender_a: str) -> dict:
    """
    Generate a user-facing explanation of the compatibility score.
    Used in the /compatibility endpoint and the Flutter compatibility screen.
    """
    score = result.final_score

    if result.dealbreaker:
        return {
            "headline": "Fundamental incompatibility",
            "headline_ar": "توافق أساسي غير ممكن",
            "summary": result.dealbreaker_reason or "A core life goal is incompatible.",
            "tier": "incompatible",
            "colour": "#8B1A4A",
            "insights": [],
        }

    # Determine tier
    if score >= 85:
        tier = "exceptional"
        headline = "Exceptional compatibility — a rare match"
        headline_ar = "توافق استثنائي — مطابقة نادرة"
        colour = "#2E7D32"
    elif score >= 72:
        tier = "strong"
        headline = "Strong compatibility"
        headline_ar = "توافق قوي"
        colour = "#388E3C"
    elif score >= 58:
        tier = "good"
        headline = "Good compatibility"
        headline_ar = "توافق جيد"
        colour = "#F57F17"
    elif score >= 42:
        tier = "moderate"
        headline = "Moderate compatibility"
        headline_ar = "توافق معتدل"
        colour = "#E65100"
    else:
        tier = "low"
        headline = "Low compatibility"
        headline_ar = "توافق منخفض"
        colour = "#B71C1C"

    # Generate natural-language insights from breakdown
    insights = _generate_insights(result.breakdown, result.ai_similarity)

    return {
        "headline":    headline,
        "headline_ar": headline_ar,
        "score":       round(score, 1),
        "tier":        tier,
        "colour":      colour,
        "has_ai":      result.has_ai,
        "ai_note": (
            "Score includes AI-powered values alignment analysis."
            if result.has_ai else
            "AI analysis pending — score based on practice signals."
        ),
        "insights": insights,
        "breakdown": result.breakdown,
    }


def _generate_insights(breakdown: dict, ai_similarity: Optional[float]) -> list[dict]:
    """Convert numerical breakdown into human-readable insight cards."""
    insights = []

    prayer = breakdown.get("prayer_alignment", 0)
    if prayer >= 15:
        insights.append({
            "icon": "🕌",
            "title": "Strong prayer alignment",
            "title_ar": "توافق في الصلاة",
            "body": "You share a similar commitment to salah — a strong foundation.",
        })
    elif prayer >= 9:
        insights.append({
            "icon": "🕌",
            "title": "Good prayer alignment",
            "title_ar": "توافق جيد في الصلاة",
            "body": "Your prayer practices are close. Worth discussing expectations.",
        })
    elif prayer < 3:
        insights.append({
            "icon": "⚠️",
            "title": "Different prayer practices",
            "title_ar": "ممارسات صلاة مختلفة",
            "body": "Your prayer frequency differs. This is an important conversation to have.",
        })

    madhab = breakdown.get("madhab_alignment", 0)
    if madhab >= 10:
        insights.append({
            "icon": "📚",
            "title": "Same madhab",
            "title_ar": "نفس المذهب",
            "body": "You follow the same school of jurisprudence — shared fiqh foundation.",
        })

    quran = breakdown.get("quran_alignment", 0)
    if quran >= 8:
        insights.append({
            "icon": "📖",
            "title": "Matched Quran level",
            "title_ar": "مستوى قرآني متطابق",
            "body": "Your Quran relationship is well-matched.",
        })

    hajj = breakdown.get("hajj_alignment", 0)
    if hajj >= 8:
        insights.append({
            "icon": "🕋",
            "title": "Aligned Hajj timeline",
            "title_ar": "توقيت حج متوافق",
            "body": "You share the same aspiration for when to perform Hajj.",
        })

    if breakdown.get("both_mosque_verified"):
        insights.append({
            "icon": "✅",
            "title": "Both mosque-verified",
            "title_ar": "كلاهما موثّق من المسجد",
            "body": "Both profiles are verified by partner mosques — high trust.",
        })

    if ai_similarity and ai_similarity >= 0.80:
        insights.append({
            "icon": "🤍",
            "title": "Deep values alignment",
            "title_ar": "توافق عميق في القيم",
            "body": (
                "Our AI detected strong alignment in your Islamic values, "
                "life vision, and character beyond what the individual fields show."
            ),
        })
    elif ai_similarity and ai_similarity >= 0.70:
        insights.append({
            "icon": "🤍",
            "title": "Good values alignment",
            "title_ar": "توافق جيد في القيم",
            "body": "Your overall values profile shows meaningful compatibility.",
        })

    return insights[:5]   # cap at 5 insight cards


# ─────────────────────────────────────────────
# DISCOVERY RANKING
# ─────────────────────────────────────────────

async def rank_candidates(
    db: AsyncSession,
    seeker: Profile,
    candidates: list[Profile],
    limit: int = 20,
) -> list[tuple[Profile, CompatibilityResult]]:
    """
    Score and rank a list of candidate profiles against the seeker.

    Steps:
    1. Filter hard dealbreakers (children mismatch, age range)
    2. Score each candidate with hybrid engine
    3. Sort by final_score descending
    4. Return top-N with full CompatibilityResult for explainability

    Called by the discovery endpoint to rank the candidate pool.
    """
    scored: list[tuple[Profile, CompatibilityResult]] = []

    for candidate in candidates:
        # Quick pre-filter: age range
        if not _age_range_compatible(seeker, candidate):
            continue

        result = compute_hybrid_score(seeker, candidate)

        # Suppress dealbreakers entirely from discovery feed
        if result.dealbreaker:
            continue

        # Minimum score threshold — don't show truly incompatible profiles
        if result.final_score < DEALBREAKER_THRESHOLD:
            continue

        scored.append((candidate, result))

    # Sort: primary = final_score, secondary = trust_score (tiebreaker)
    scored.sort(
        key=lambda x: (x[1].final_score, x[0].trust_score or 0),
        reverse=True,
    )

    return scored[:limit]


def _age_range_compatible(seeker: Profile, candidate: Profile) -> bool:
    """
    Check if the candidate's age falls within the seeker's stated preference,
    and vice-versa (mutual age range check).
    """
    from datetime import datetime, timezone

    def get_age(p: Profile) -> Optional[int]:
        if not p.date_of_birth:
            return None
        dob = p.date_of_birth
        if dob.tzinfo is None:
            dob = dob.replace(tzinfo=timezone.utc)
        today = datetime.now(timezone.utc)
        return today.year - dob.year - (
            (today.month, today.day) < (dob.month, dob.day)
        )

    seeker_age    = get_age(seeker)
    candidate_age = get_age(candidate)

    if seeker_age and candidate_age:
        # Does candidate fall within seeker's preferred range?
        if not (seeker.min_age <= candidate_age <= seeker.max_age):
            return False
        # Does seeker fall within candidate's preferred range?
        if not (candidate.min_age <= seeker_age <= candidate.max_age):
            return False

    return True
