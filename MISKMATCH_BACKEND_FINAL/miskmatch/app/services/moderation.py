"""
MiskMatch — Islamic Content Moderation Service
AI-powered message moderation trained on Islamic values.

Every message passes through this service before delivery.
Inappropriate content is held, user warned, wali notified.

Moderation layers:
  1. Fast rule-based filter (regex/keywords) — <1ms
  2. OpenAI GPT-4o-mini classifier — ~300ms
  3. Final decision with reason

Islamic content policy:
  ✓ Respectful greetings and conversation
  ✓ Discussing deen, family, life goals
  ✓ Sharing about work, hobbies, culture
  ✗ Romantic/flirtatious language outside Islamic norms
  ✗ Private meeting arrangements outside family knowledge
  ✗ Requests for photos not yet approved
  ✗ Inappropriate content of any kind
  ✗ Pressure tactics or manipulation
"""

import logging
import re
from dataclasses import dataclass
from typing import Optional

from app.core.config import settings

logger = logging.getLogger(__name__)


# ─────────────────────────────────────────────
# MODERATION RESULT
# ─────────────────────────────────────────────

@dataclass
class ModerationResult:
    passed:      bool
    reason:      Optional[str]   = None
    category:    Optional[str]   = None
    confidence:  float           = 1.0
    layer:       str             = "unknown"  # "fast" | "ai" | "bypass"


# ─────────────────────────────────────────────
# FAST RULE-BASED FILTER
# ─────────────────────────────────────────────

# Explicit violations — immediate block regardless of context
HARD_BLOCK_PATTERNS = [
    r"\b(nude|naked|porn|xxx)\b",
    r"\bsex(ual|y|ting)?\b",
    r"\b(meet me alone|come to my house|my address is)\b",
    r"\b(send (me )?(your )?(photos?|pics?|pictures?))\b",
    r"\b(snapchat|whatsapp|telegram) (me|number)\b",
    r"(?i)(i love you|i'm in love with you)",
    r"(?i)(you're so hot|you are so hot|you're sexy|you are sexy|so sexy|looking sexy)",
    r"(?i)(i want to kiss|i want to touch|i want to hold you)",
]

# Soft warnings — flagged for AI review
SOFT_FLAG_PATTERNS = [
    r"(?i)(meet without|without (your|the) (wali|guardian|family))",
    r"(?i)(just between us|keep this secret|don't tell)",
    r"(?i)(give me your number|what's your number|call me)",
]

_hard_patterns = [re.compile(p, re.IGNORECASE) for p in HARD_BLOCK_PATTERNS]
_soft_patterns = [re.compile(p, re.IGNORECASE) for p in SOFT_FLAG_PATTERNS]


def fast_filter(content: str) -> ModerationResult:
    """
    Rule-based pre-filter. Runs before AI call.
    Returns immediately on hard violations.
    """
    content_lower = content.lower().strip()

    # Hard block
    for pattern in _hard_patterns:
        if pattern.search(content_lower):
            return ModerationResult(
                passed=False,
                reason="Message contains content that is not appropriate for this platform.",
                category="explicit_violation",
                confidence=1.0,
                layer="fast",
            )

    # Soft flag — still passes, but AI will review
    for pattern in _soft_patterns:
        if pattern.search(content_lower):
            return ModerationResult(
                passed=True,  # passes but flagged
                reason="Message flagged for guardian review.",
                category="soft_flag",
                confidence=0.7,
                layer="fast",
            )

    return ModerationResult(passed=True, layer="fast")


# ─────────────────────────────────────────────
# AI MODERATION
# ─────────────────────────────────────────────

MODERATION_SYSTEM_PROMPT = """You are the content moderation system for MiskMatch, an Islamic matrimony platform.

Your job is to evaluate messages sent between matched Muslim individuals seeking marriage.

Islamic content policy:
ALLOWED:
- Respectful introductions and greetings (including Islamic greetings)
- Discussing one's deen, values, beliefs, and Islamic practices  
- Sharing about family background, education, career, hobbies
- Questions about life goals, marriage expectations, Islamic compatibility
- Discussing Quran, hadith, Islamic knowledge
- Respectful compliments about character or values
- Discussing practical matters about future life together

NOT ALLOWED:
- Romantic or flirtatious language that crosses Islamic modesty boundaries
- Attempting to arrange private meetings without family/guardian knowledge
- Requesting personal contact information (phone, social media, email)
- Any sexual or inappropriate content whatsoever
- Manipulation, pressure tactics, or controlling language
- Attempts to bypass the guardian (wali) system
- Content that would embarrass if a family member read it

Respond ONLY with JSON:
{
  "passed": true/false,
  "reason": "brief reason if failed, null if passed",
  "category": "category if failed, null if passed"
}

Categories if failing: "romantic_boundary", "contact_request", "privacy_bypass", "inappropriate", "manipulation"
"""


async def ai_moderate(content: str) -> ModerationResult:
    """
    GPT-4o-mini based Islamic content moderation.
    Called only when fast filter doesn't hard-block.
    """
    if not settings.OPENAI_API_KEY:
        # No AI key configured — pass through in dev
        logger.debug("AI moderation skipped (no API key)")
        return ModerationResult(passed=True, layer="bypass", reason="AI moderation not configured")

    try:
        import openai
        client = openai.AsyncOpenAI(api_key=settings.OPENAI_API_KEY)

        response = await client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {"role": "system", "content": MODERATION_SYSTEM_PROMPT},
                {"role": "user",   "content": f"Message to moderate: {content}"},
            ],
            max_tokens=120,
            temperature=0.0,      # deterministic
            response_format={"type": "json_object"},
        )

        import json
        result = json.loads(response.choices[0].message.content)

        return ModerationResult(
            passed=result.get("passed", True),
            reason=result.get("reason"),
            category=result.get("category"),
            confidence=0.9,
            layer="ai",
        )

    except Exception as e:
        logger.error(f"AI moderation failed: {e}")
        # On AI failure → pass through (log for manual review)
        return ModerationResult(
            passed=True,
            layer="ai_error",
            reason=f"AI moderation unavailable: {str(e)[:50]}",
        )


# ─────────────────────────────────────────────
# MAIN MODERATION PIPELINE
# ─────────────────────────────────────────────

async def moderate_message(content: str) -> ModerationResult:
    """
    Full moderation pipeline:
    1. Fast rule-based filter (always runs)
    2. AI classifier (runs unless fast filter hard-blocked)

    Returns final ModerationResult.
    """
    # Layer 1: fast filter
    fast_result = fast_filter(content)

    # Hard block — skip AI, save cost
    if not fast_result.passed and fast_result.category == "explicit_violation":
        logger.warning(f"Hard block: '{content[:50]}...' [{fast_result.category}]")
        return fast_result

    # Layer 2: AI moderation
    # Only call AI for non-trivial messages (saves tokens/cost)
    if len(content.split()) >= 3:  # at least 3 words
        ai_result = await ai_moderate(content)

        # AI overrides if it finds a violation
        if not ai_result.passed:
            logger.warning(
                f"AI block: '{content[:50]}...' "
                f"[{ai_result.category}] confidence={ai_result.confidence}"
            )
            return ai_result

    return fast_result


# ─────────────────────────────────────────────
# WALI ALERT
# ─────────────────────────────────────────────

async def should_alert_wali(result: ModerationResult) -> bool:
    """
    Determine if wali should be proactively alerted about a moderation event.
    Hard violations always alert. Soft flags alert if repeated.
    """
    return (
        not result.passed
        or result.category in ("explicit_violation", "privacy_bypass", "romantic_boundary")
    )
