"""
MiskMatch — Public Reports Router

User-facing moderation endpoints. The administrative review side
(list / detail / resolve) lives in app.routers.admin under /admin/reports.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
USER ENDPOINTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
POST   /reports         File a report against another user
GET    /reports/me      List reports I have submitted
"""

import logging
from typing import Annotated, List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.sanitize import sanitize_text
from app.models.models import Report, User, UserStatus
from app.routers.auth import get_current_active_user
from app.schemas.admin import CreateReportRequest, ReportResponse

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/reports", tags=["Moderation — Reports"])

CurrentUser = Annotated[User, Depends(get_current_active_user)]
DB          = Annotated[AsyncSession, Depends(get_db)]


# ─────────────────────────────────────────────
# CREATE REPORT
# ─────────────────────────────────────────────

@router.post(
    "",
    response_model=ReportResponse,
    status_code=status.HTTP_201_CREATED,
    summary="File a report against another user",
)
async def create_report(
    body: CreateReportRequest,
    current_user: CurrentUser,
    db: DB,
):
    """
    Submit a safety report against another user.

    The report enters the moderation queue at status='pending'.
    Admins review and resolve via /admin/reports/{id}/resolve.

    Set is_block=true to also block the reported user (mutual hide
    from discovery, no new matches).
    """
    if body.reported_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot report yourself.",
        )

    # Verify the reported user exists and is not deleted
    result = await db.execute(
        select(User).where(User.id == body.reported_id)
    )
    reported_user = result.scalar_one_or_none()
    if reported_user is None or reported_user.status == UserStatus.DEACTIVATED:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Reported user not found.",
        )

    # Sanitize the description (HTML-strip + trim)
    description = sanitize_text(body.description or "").strip() or None

    report = Report(
        reporter_id=current_user.id,
        reported_id=body.reported_id,
        reason=body.reason.strip(),
        description=description,
        is_block=body.is_block,
        status="pending",
    )
    db.add(report)
    await db.commit()
    await db.refresh(report)

    logger.info(
        "Report filed: reporter=%s reported=%s reason=%s block=%s",
        current_user.id,
        body.reported_id,
        body.reason,
        body.is_block,
    )

    return ReportResponse.model_validate(report)


# ─────────────────────────────────────────────
# LIST MY REPORTS
# ─────────────────────────────────────────────

@router.get(
    "/me",
    response_model=List[ReportResponse],
    summary="List reports I have submitted",
)
async def list_my_reports(
    current_user: CurrentUser,
    db: DB,
):
    """
    Returns all reports filed by the current user, newest first.
    Useful for letting users track the status of their submissions.
    """
    result = await db.execute(
        select(Report)
        .where(Report.reporter_id == current_user.id)
        .order_by(Report.created_at.desc())
        .limit(100)
    )
    reports = result.scalars().all()
    return [ReportResponse.model_validate(r) for r in reports]
