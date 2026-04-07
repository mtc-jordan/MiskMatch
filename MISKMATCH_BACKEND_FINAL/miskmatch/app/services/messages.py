"""
MiskMatch — Message Service
Business logic for supervised chat between matched users.
Every message is moderated before delivery.
Wali has full read access with consent.
"""

import logging
from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

from sqlalchemy import select, and_, or_, func, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.models import (
    Match, Message, MessageStatus, MatchStatus,
    WaliRelationship, Profile, User, Notification,
)
from app.services.moderation import moderate_message, should_alert_wali

logger = logging.getLogger(__name__)


# ─────────────────────────────────────────────
# SEND MESSAGE
# ─────────────────────────────────────────────

async def send_message(
    db: AsyncSession,
    sender_id: UUID,
    match_id: UUID,
    content: str,
    content_type: str = "text",
    media_url: Optional[str] = None,
) -> tuple[Message, bool]:
    """
    Send a message in a match conversation.

    Steps:
    1. Verify match is ACTIVE and sender is participant
    2. Run AI Islamic content moderation
    3. Save message (passed or flagged)
    4. Return (message, was_moderated)

    Raises:
        ValueError: if match not found, not active, or sender not participant
    """
    # Load and validate match
    match = await _get_active_match(db, match_id, sender_id)

    # Run moderation pipeline
    mod_result = await moderate_message(content)

    # Create message record
    msg = Message(
        match_id=match_id,
        sender_id=sender_id,
        content=content,
        content_type=content_type,
        media_url=media_url,
        status=MessageStatus.SENT,
        moderation_passed=mod_result.passed,
        moderation_reason=mod_result.reason,
    )
    db.add(msg)
    await db.flush()

    # Flag moderated messages
    if not mod_result.passed:
        msg.status = MessageStatus.FLAGGED
        logger.warning(
            f"Message flagged: match={match_id} sender={sender_id} "
            f"reason={mod_result.reason}"
        )

        # Alert wali if needed
        if await should_alert_wali(mod_result):
            await _notify_wali_flagged_message(db, match, sender_id, mod_result.reason)

    return msg, not mod_result.passed


async def _get_active_match(
    db: AsyncSession,
    match_id: UUID,
    user_id: UUID,
) -> Match:
    """Load match and verify it's active and user is a participant."""
    result = await db.execute(
        select(Match).where(
            and_(
                Match.id == match_id,
                Match.status == MatchStatus.ACTIVE,
                or_(
                    Match.sender_id   == user_id,
                    Match.receiver_id == user_id,
                ),
            )
        )
    )
    match = result.scalar_one_or_none()
    if not match:
        raise ValueError(
            "Match not found, not active, or you are not a participant. "
            "Messaging is only available in approved active matches."
        )
    return match


# ─────────────────────────────────────────────
# READ MESSAGES
# ─────────────────────────────────────────────

async def get_messages(
    db: AsyncSession,
    match_id: UUID,
    user_id: UUID,
    page: int = 1,
    page_size: int = 50,
    before_id: Optional[UUID] = None,
) -> tuple[list[Message], int]:
    """
    Get paginated messages for a match.
    User must be a participant OR a registered wali for one of the participants.

    Messages returned newest-first (standard chat UX).
    """
    # Verify access
    has_access = await _can_access_messages(db, match_id, user_id)
    if not has_access:
        raise ValueError("Access denied. You are not a participant or guardian in this match.")

    stmt = select(Message).where(
        and_(
            Message.match_id == match_id,
            # Don't show flagged messages to regular users
            or_(
                Message.status != MessageStatus.FLAGGED,
                Message.sender_id == user_id,  # own flagged messages visible to sender
            ),
        )
    )

    # Cursor pagination (before_id for infinite scroll)
    if before_id:
        before_result = await db.execute(
            select(Message.created_at).where(Message.id == before_id)
        )
        before_ts = before_result.scalar_one_or_none()
        if before_ts:
            stmt = stmt.where(Message.created_at < before_ts)

    # Count
    count_result = await db.execute(
        select(func.count()).select_from(
            select(Message).where(Message.match_id == match_id).subquery()
        )
    )
    total = count_result.scalar() or 0

    # Fetch newest first
    stmt = stmt.order_by(Message.created_at.desc()).limit(page_size)
    result = await db.execute(stmt)
    messages = result.scalars().all()

    return list(reversed(messages)), total  # reverse so oldest-first for display


async def _can_access_messages(
    db: AsyncSession,
    match_id: UUID,
    user_id: UUID,
) -> bool:
    """
    Returns True if user_id can read messages in match_id.
    Allowed: direct participant OR registered wali for either participant.
    """
    # Direct participant check
    match_result = await db.execute(
        select(Match).where(
            and_(
                Match.id == match_id,
                or_(
                    Match.sender_id   == user_id,
                    Match.receiver_id == user_id,
                ),
            )
        )
    )
    if match_result.scalar_one_or_none():
        return True

    # Wali check — load match first
    match_result2 = await db.execute(select(Match).where(Match.id == match_id))
    match = match_result2.scalar_one_or_none()
    if not match:
        return False

    for ward_id in [match.sender_id, match.receiver_id]:
        wali_result = await db.execute(
            select(WaliRelationship).where(
                and_(
                    WaliRelationship.user_id      == ward_id,
                    WaliRelationship.wali_user_id == user_id,
                    WaliRelationship.is_active    == True,
                    WaliRelationship.invitation_accepted == True,
                )
            )
        )
        if wali_result.scalar_one_or_none():
            return True

    return False


# ─────────────────────────────────────────────
# READ RECEIPTS
# ─────────────────────────────────────────────

async def mark_messages_read(
    db: AsyncSession,
    match_id: UUID,
    reader_id: UUID,
    message_ids: list[UUID],
) -> int:
    """
    Mark specific messages as read by the current user.
    Only marks messages NOT sent by the reader (can't mark own as read).

    Returns number of messages marked.
    """
    result = await db.execute(
        update(Message)
        .where(
            and_(
                Message.id.in_(message_ids),
                Message.match_id  == match_id,
                Message.sender_id != reader_id,  # can't mark own messages
                Message.status    == MessageStatus.DELIVERED,
            )
        )
        .values(status=MessageStatus.READ)
        .returning(Message.id)
    )
    updated = result.fetchall()
    await db.flush()
    return len(updated)


async def mark_delivered(
    db: AsyncSession,
    message_id: UUID,
) -> None:
    """
    Mark a message as delivered when recipient's WS receives it.
    Called by the WebSocket handler after successful delivery.
    """
    await db.execute(
        update(Message)
        .where(
            and_(
                Message.id     == message_id,
                Message.status == MessageStatus.SENT,
            )
        )
        .values(status=MessageStatus.DELIVERED)
    )
    await db.flush()


# ─────────────────────────────────────────────
# WALI PORTAL
# ─────────────────────────────────────────────

async def get_wali_conversations(
    db: AsyncSession,
    wali_user_id: UUID,
) -> list[dict]:
    """
    Get all conversations the wali has visibility into.
    Returns summary cards for the Wali Portal dashboard.
    """
    # Find all active wards
    wards_result = await db.execute(
        select(WaliRelationship).where(
            and_(
                WaliRelationship.wali_user_id    == wali_user_id,
                WaliRelationship.is_active       == True,
                WaliRelationship.invitation_accepted == True,
                WaliRelationship.can_view_messages   == True,
            )
        )
    )
    wards = wards_result.scalars().all()

    summaries = []
    for ward_rel in wards:
        ward_id = ward_rel.user_id

        # Get ward's profile
        ward_profile_result = await db.execute(
            select(Profile).where(Profile.user_id == ward_id)
        )
        ward_profile = ward_profile_result.scalar_one_or_none()

        # Get all ACTIVE matches for this ward
        matches_result = await db.execute(
            select(Match).where(
                and_(
                    Match.status == MatchStatus.ACTIVE,
                    or_(
                        Match.sender_id   == ward_id,
                        Match.receiver_id == ward_id,
                    ),
                )
            )
        )
        matches = matches_result.scalars().all()

        for match in matches:
            other_id = (
                match.receiver_id
                if match.sender_id == ward_id
                else match.sender_id
            )

            other_profile_result = await db.execute(
                select(Profile).where(Profile.user_id == other_id)
            )
            other_profile = other_profile_result.scalar_one_or_none()

            # Latest message
            latest_msg_result = await db.execute(
                select(Message)
                .where(Message.match_id == match.id)
                .order_by(Message.created_at.desc())
                .limit(1)
            )
            latest_msg = latest_msg_result.scalar_one_or_none()

            # Message stats
            stats_result = await db.execute(
                select(
                    func.count(Message.id).label("total"),
                    func.sum(
                        (Message.status == MessageStatus.FLAGGED).cast(int)
                    ).label("flagged"),
                ).where(Message.match_id == match.id)
            )
            stats = stats_result.one()

            summaries.append({
                "match_id":        str(match.id),
                "ward_name":       ward_profile.first_name if ward_profile else "Ward",
                "other_name":      other_profile.first_name if other_profile else "Match",
                "last_message":    latest_msg.content[:100] if latest_msg else None,
                "last_message_at": latest_msg.created_at if latest_msg else None,
                "match_status":    match.status,
                "message_count":   stats.total or 0,
                "flagged_count":   stats.flagged or 0,
                "unread_count":    0,  # TODO: per-wali read tracking
            })

    return summaries


async def get_wali_messages(
    db: AsyncSession,
    match_id: UUID,
    wali_user_id: UUID,
    page: int = 1,
    page_size: int = 50,
) -> tuple[list[Message], int]:
    """
    Wali reads all messages in a match — including flagged ones.
    Returns full message history with moderation metadata.
    """
    # Verify wali has access to this match
    has_access = await _can_access_messages(db, match_id, wali_user_id)
    if not has_access:
        raise ValueError("You do not have guardian access to this conversation.")

    # Wali sees ALL messages including flagged
    stmt = (
        select(Message)
        .where(Message.match_id == match_id)
        .order_by(Message.created_at.asc())
    )

    count_result = await db.execute(
        select(func.count()).select_from(
            select(Message).where(Message.match_id == match_id).subquery()
        )
    )
    total = count_result.scalar() or 0

    stmt = stmt.offset((page - 1) * page_size).limit(page_size)
    result = await db.execute(stmt)
    return result.scalars().all(), total


# ─────────────────────────────────────────────
# REPORT MESSAGE
# ─────────────────────────────────────────────

async def report_message(
    db: AsyncSession,
    message_id: UUID,
    reporter_id: UUID,
    reason: str,
) -> Message:
    """Flag a message for manual admin review."""
    result = await db.execute(select(Message).where(Message.id == message_id))
    msg = result.scalar_one_or_none()

    if not msg:
        raise ValueError("Message not found.")

    if msg.sender_id == reporter_id:
        raise ValueError("You cannot report your own message.")

    msg.status = MessageStatus.FLAGGED
    msg.moderation_reason = f"User report: {reason}"
    await db.flush()

    logger.info(f"Message {message_id} reported by {reporter_id}: {reason}")
    return msg


# ─────────────────────────────────────────────
# NOTIFICATIONS
# ─────────────────────────────────────────────

async def _notify_wali_flagged_message(
    db: AsyncSession,
    match: Match,
    sender_id: UUID,
    reason: Optional[str],
) -> None:
    """Notify wali when a message is flagged by moderation."""
    for ward_id in [match.sender_id, match.receiver_id]:
        wali_result = await db.execute(
            select(WaliRelationship).where(
                and_(
                    WaliRelationship.user_id      == ward_id,
                    WaliRelationship.is_active    == True,
                    WaliRelationship.wali_user_id.isnot(None),
                )
            )
        )
        wali_rel = wali_result.scalar_one_or_none()
        if wali_rel and wali_rel.wali_user_id:
            notif = Notification(
                user_id=wali_rel.wali_user_id,
                title="Message flagged for review",
                title_ar="رسالة تحتاج مراجعة",
                body="A message in one of your ward's conversations was flagged by our system.",
                body_ar="تم الإبلاغ عن رسالة في إحدى محادثات مولاك من قِبَل نظامنا.",
                notification_type="message_flagged",
                reference_id=match.id,
                reference_type="match",
            )
            db.add(notif)

    await db.flush()
