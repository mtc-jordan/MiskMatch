"""
MiskMatch — Admin Dashboard Router
Moderation, user management, and analytics endpoints.
"""

from datetime import datetime, timezone, timedelta
from typing import Annotated, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, func, case, and_, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.models.models import (
    User, UserRole, UserStatus,
    Profile, Match, MatchStatus,
    Message, MessageStatus,
    Report, Call, Game,
)
from app.routers.auth import get_current_active_user
from app.schemas.admin import (
    DashboardOverview, AnalyticsResponse, RegistrationPoint,
    AdminUserSummary, AdminUserListResponse,
    AdminUserDetailResponse, AdminUserProfileDetail,
    AdminMatchSummary, AdminReportSummary,
    UpdateUserStatusRequest, UpdateUserStatusResponse,
    UpdateUserRoleRequest, UpdateUserRoleResponse,
    ReportResponse, ReportListResponse,
    ReportDetailResponse, ReportDetailUser,
    ResolveReportRequest, ResolveReportResponse,
    FlaggedMessageResponse, FlaggedMessageListResponse,
    AdminMatchResponse, AdminMatchListResponse,
    MatchFunnelStats,
)

router = APIRouter(prefix="/admin", tags=["Admin Dashboard"])

# Type aliases
DB = Annotated[AsyncSession, Depends(get_db)]


# ─────────────────────────────────────────────
# ADMIN DEPENDENCY
# ─────────────────────────────────────────────

async def admin_required(
    current_user: Annotated[User, Depends(get_current_active_user)],
) -> User:
    """Only allow users with ADMIN role."""
    if current_user.role != UserRole.ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required",
        )
    return current_user

AdminUser = Annotated[User, Depends(admin_required)]


# ─────────────────────────────────────────────
# ANALYTICS DASHBOARD
# ─────────────────────────────────────────────

@router.get(
    "/dashboard",
    response_model=DashboardOverview,
    summary="Dashboard overview stats",
)
async def get_dashboard(
    admin: AdminUser,
    db: DB,
):
    """
    Returns high-level platform statistics:
    total users, active matches, messages today, pending reports.
    """
    now = datetime.now(timezone.utc)
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)

    # User counts by status
    user_counts = await db.execute(
        select(
            func.count().label("total"),
            func.count().filter(User.status == UserStatus.ACTIVE).label("active"),
            func.count().filter(User.status == UserStatus.PENDING).label("pending"),
            func.count().filter(User.status == UserStatus.BANNED).label("banned"),
        ).select_from(User)
    )
    uc = user_counts.one()

    # Active matches (MUTUAL, APPROVED, ACTIVE)
    active_matches_result = await db.execute(
        select(func.count()).select_from(Match).where(
            Match.status.in_([MatchStatus.MUTUAL, MatchStatus.APPROVED, MatchStatus.ACTIVE])
        )
    )
    active_matches = active_matches_result.scalar() or 0

    # Total matches
    total_matches_result = await db.execute(
        select(func.count()).select_from(Match)
    )
    total_matches = total_matches_result.scalar() or 0

    # Messages today
    messages_today_result = await db.execute(
        select(func.count()).select_from(Message).where(
            Message.created_at >= today_start
        )
    )
    messages_today = messages_today_result.scalar() or 0

    # Pending reports
    reports_pending_result = await db.execute(
        select(func.count()).select_from(Report).where(
            Report.status == "pending"
        )
    )
    reports_pending = reports_pending_result.scalar() or 0

    return DashboardOverview(
        total_users=uc.total,
        active_users=uc.active,
        pending_users=uc.pending,
        banned_users=uc.banned,
        active_matches=active_matches,
        total_matches=total_matches,
        messages_today=messages_today,
        reports_pending=reports_pending,
    )


@router.get(
    "/analytics",
    response_model=AnalyticsResponse,
    summary="Detailed analytics metrics",
)
async def get_analytics(
    admin: AdminUser,
    db: DB,
    days: int = Query(30, ge=1, le=365, description="Number of days to look back"),
):
    """
    Detailed metrics: registrations over time, match success rate,
    average messages per match, nikah count, games played, calls today.
    """
    now = datetime.now(timezone.utc)
    since = now - timedelta(days=days)
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)

    # Registrations over time (daily)
    reg_query = await db.execute(
        select(
            func.date_trunc("day", User.created_at).label("day"),
            func.count().label("count"),
        )
        .where(User.created_at >= since)
        .group_by(func.date_trunc("day", User.created_at))
        .order_by(func.date_trunc("day", User.created_at))
    )
    registrations = [
        RegistrationPoint(date=str(row.day.date()), count=row.count)
        for row in reg_query.all()
    ]

    # Match success rate: matches that went beyond PENDING / total matches
    total_matches_result = await db.execute(
        select(func.count()).select_from(Match)
    )
    total_matches = total_matches_result.scalar() or 0

    successful_matches_result = await db.execute(
        select(func.count()).select_from(Match).where(
            Match.status.in_([
                MatchStatus.MUTUAL, MatchStatus.APPROVED,
                MatchStatus.ACTIVE, MatchStatus.NIKAH,
            ])
        )
    )
    successful_matches = successful_matches_result.scalar() or 0
    match_success_rate = (
        round((successful_matches / total_matches) * 100, 2)
        if total_matches > 0 else 0.0
    )

    # Average messages per match
    avg_msg_result = await db.execute(
        select(func.avg(func.count()))
        .select_from(Message)
        .group_by(Message.match_id)
    )
    avg_msg_row = avg_msg_result.scalar()
    avg_messages = round(float(avg_msg_row), 2) if avg_msg_row else 0.0

    # Total nikah
    nikah_result = await db.execute(
        select(func.count()).select_from(Match).where(
            Match.status == MatchStatus.NIKAH
        )
    )
    total_nikah = nikah_result.scalar() or 0

    # Total games played
    games_result = await db.execute(
        select(func.count()).select_from(Game)
    )
    total_games = games_result.scalar() or 0

    # Calls today
    calls_today_result = await db.execute(
        select(func.count()).select_from(Call).where(
            Call.created_at >= today_start
        )
    )
    active_calls_today = calls_today_result.scalar() or 0

    return AnalyticsResponse(
        registrations_over_time=registrations,
        match_success_rate=match_success_rate,
        avg_messages_per_match=avg_messages,
        total_nikah=total_nikah,
        total_games_played=total_games,
        active_calls_today=active_calls_today,
    )


# ─────────────────────────────────────────────
# USER MANAGEMENT
# ─────────────────────────────────────────────

@router.get(
    "/users",
    response_model=AdminUserListResponse,
    summary="List users with pagination and search",
)
async def list_users(
    admin: AdminUser,
    db: DB,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    search: Optional[str] = Query(None, description="Search by phone or name"),
    status_filter: Optional[UserStatus] = Query(None, alias="status", description="Filter by user status"),
    role_filter: Optional[UserRole] = Query(None, alias="role", description="Filter by user role"),
):
    """
    List all users with pagination. Supports search by phone/name
    and filter by status or role.
    """
    # Base query
    query = select(User)
    count_query = select(func.count()).select_from(User)

    # Filters
    conditions = []
    if status_filter:
        conditions.append(User.status == status_filter)
    if role_filter:
        conditions.append(User.role == role_filter)
    if search:
        search_pattern = f"%{search}%"
        # Search in phone and join to profile for name search
        phone_cond = User.phone.ilike(search_pattern)
        email_cond = User.email.ilike(search_pattern)
        conditions.append(or_(phone_cond, email_cond))

    if conditions:
        combined = and_(*conditions)
        query = query.where(combined)
        count_query = count_query.where(combined)

    # Total count
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0

    # Paginated results
    offset = (page - 1) * page_size
    query = query.order_by(User.created_at.desc()).offset(offset).limit(page_size)
    result = await db.execute(query)
    users = result.scalars().all()

    return AdminUserListResponse(
        users=[
            AdminUserSummary(
                id=u.id,
                phone=u.phone,
                email=u.email,
                role=u.role,
                status=u.status,
                gender=u.gender,
                phone_verified=u.phone_verified,
                onboarding_completed=u.onboarding_completed,
                subscription_tier=u.subscription_tier,
                created_at=u.created_at,
                last_seen_at=u.last_seen_at,
            )
            for u in users
        ],
        total=total,
        page=page,
        page_size=page_size,
    )


@router.get(
    "/users/{user_id}",
    response_model=AdminUserDetailResponse,
    summary="Full user detail with profile, matches, reports",
)
async def get_user_detail(
    user_id: UUID,
    admin: AdminUser,
    db: DB,
):
    """
    Returns complete user information including profile data,
    all matches, and all reports (as reporter and reported).
    """
    # Fetch user
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    user_summary = AdminUserSummary(
        id=user.id,
        phone=user.phone,
        email=user.email,
        role=user.role,
        status=user.status,
        gender=user.gender,
        phone_verified=user.phone_verified,
        onboarding_completed=user.onboarding_completed,
        subscription_tier=user.subscription_tier,
        created_at=user.created_at,
        last_seen_at=user.last_seen_at,
    )

    # Fetch profile
    profile_result = await db.execute(
        select(Profile).where(Profile.user_id == user_id)
    )
    profile = profile_result.scalar_one_or_none()
    profile_detail = None
    if profile:
        profile_detail = AdminUserProfileDetail.model_validate(profile)

    # Fetch matches (as sender or receiver)
    matches_result = await db.execute(
        select(Match).where(
            or_(Match.sender_id == user_id, Match.receiver_id == user_id)
        ).order_by(Match.created_at.desc()).limit(50)
    )
    matches = matches_result.scalars().all()

    match_summaries = []
    for m in matches:
        other_id = m.receiver_id if m.sender_id == user_id else m.sender_id
        other_result = await db.execute(select(User.phone).where(User.id == other_id))
        other_phone = other_result.scalar() or "unknown"
        match_summaries.append(AdminMatchSummary(
            id=m.id,
            other_user_id=other_id,
            other_user_phone=other_phone,
            status=m.status,
            compatibility_score=m.compatibility_score,
            created_at=m.created_at,
        ))

    # Fetch reports (as reporter or reported)
    reports_result = await db.execute(
        select(Report).where(
            or_(Report.reporter_id == user_id, Report.reported_id == user_id)
        ).order_by(Report.created_at.desc()).limit(50)
    )
    reports = reports_result.scalars().all()

    report_summaries = []
    for r in reports:
        if r.reporter_id == user_id:
            role = "reporter"
            other_id = r.reported_id
        else:
            role = "reported"
            other_id = r.reporter_id
        other_result = await db.execute(select(User.phone).where(User.id == other_id))
        other_phone = other_result.scalar() or "unknown"
        report_summaries.append(AdminReportSummary(
            id=r.id,
            reason=r.reason,
            status=r.status,
            role=role,
            other_user_phone=other_phone,
            created_at=r.created_at,
        ))

    return AdminUserDetailResponse(
        user=user_summary,
        profile=profile_detail,
        matches=match_summaries,
        reports=report_summaries,
    )


@router.put(
    "/users/{user_id}/status",
    response_model=UpdateUserStatusResponse,
    summary="Ban, unban, or reactivate a user",
)
async def update_user_status(
    user_id: UUID,
    body: UpdateUserStatusRequest,
    admin: AdminUser,
    db: DB,
):
    """
    Change a user's status. Used for banning, unbanning,
    suspending, or reactivating accounts.
    """
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    if user.role == UserRole.ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cannot change status of another admin",
        )

    old_status = user.status
    user.status = body.status

    # If banning, also close active matches
    if body.status == UserStatus.BANNED:
        matches_result = await db.execute(
            select(Match).where(
                or_(Match.sender_id == user_id, Match.receiver_id == user_id),
                Match.status.in_([
                    MatchStatus.PENDING, MatchStatus.MUTUAL,
                    MatchStatus.APPROVED, MatchStatus.ACTIVE,
                ]),
            )
        )
        active_matches = matches_result.scalars().all()
        for match in active_matches:
            match.status = MatchStatus.CLOSED
            match.closed_reason = f"user_banned: {body.reason or 'admin action'}"

    await db.commit()

    action_map = {
        UserStatus.ACTIVE: "reactivated",
        UserStatus.BANNED: "banned",
        UserStatus.SUSPENDED: "suspended",
        UserStatus.DEACTIVATED: "deactivated",
        UserStatus.PENDING: "set to pending",
    }
    action_word = action_map.get(body.status, "updated")

    return UpdateUserStatusResponse(
        user_id=user.id,
        old_status=old_status,
        new_status=user.status,
        message=f"User {action_word} successfully",
    )


@router.put(
    "/users/{user_id}/role",
    response_model=UpdateUserRoleResponse,
    summary="Change user role (e.g., promote to moderator)",
)
async def update_user_role(
    user_id: UUID,
    body: UpdateUserRoleRequest,
    admin: AdminUser,
    db: DB,
):
    """
    Change a user's role. Used to promote users to WALI or SCHOLAR,
    or demote back to USER.
    """
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # Prevent creating new admins through this endpoint
    if body.role == UserRole.ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cannot promote to admin through this endpoint",
        )

    old_role = user.role
    user.role = body.role
    await db.commit()

    return UpdateUserRoleResponse(
        user_id=user.id,
        old_role=old_role,
        new_role=user.role,
        message=f"User role changed from {old_role.value} to {user.role.value}",
    )


# ─────────────────────────────────────────────
# MODERATION — REPORTS
# ─────────────────────────────────────────────

@router.get(
    "/reports",
    response_model=ReportListResponse,
    summary="List reports with pagination and status filter",
)
async def list_reports(
    admin: AdminUser,
    db: DB,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    status_filter: Optional[str] = Query(
        None, alias="status",
        description="Filter by report status: pending, reviewed, resolved",
    ),
):
    """
    List all reports. Filter by status to focus on
    pending reports that need attention.
    """
    query = select(Report)
    count_query = select(func.count()).select_from(Report)

    if status_filter:
        query = query.where(Report.status == status_filter)
        count_query = count_query.where(Report.status == status_filter)

    # Total
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0

    # Paginated
    offset = (page - 1) * page_size
    query = query.order_by(Report.created_at.desc()).offset(offset).limit(page_size)
    result = await db.execute(query)
    reports = result.scalars().all()

    return ReportListResponse(
        reports=[ReportResponse.model_validate(r) for r in reports],
        total=total,
        page=page,
        page_size=page_size,
    )


@router.get(
    "/reports/{report_id}",
    response_model=ReportDetailResponse,
    summary="Report detail with reporter and reported user context",
)
async def get_report_detail(
    report_id: UUID,
    admin: AdminUser,
    db: DB,
):
    """
    Returns full report details including reporter and reported
    user information for context during review.
    """
    result = await db.execute(select(Report).where(Report.id == report_id))
    report = result.scalar_one_or_none()
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")

    # Fetch reporter
    reporter_result = await db.execute(select(User).where(User.id == report.reporter_id))
    reporter = reporter_result.scalar_one_or_none()

    # Fetch reported
    reported_result = await db.execute(select(User).where(User.id == report.reported_id))
    reported = reported_result.scalar_one_or_none()

    async def _build_report_user(user: User) -> ReportDetailUser:
        profile_result = await db.execute(
            select(Profile).where(Profile.user_id == user.id)
        )
        profile = profile_result.scalar_one_or_none()
        return ReportDetailUser(
            id=user.id,
            phone=user.phone,
            email=user.email,
            status=user.status,
            first_name=profile.first_name if profile else None,
            last_name=profile.last_name if profile else None,
        )

    return ReportDetailResponse(
        report=ReportResponse.model_validate(report),
        reporter=await _build_report_user(reporter) if reporter else ReportDetailUser(
            id=report.reporter_id, phone="deleted", status=UserStatus.DEACTIVATED,
        ),
        reported=await _build_report_user(reported) if reported else ReportDetailUser(
            id=report.reported_id, phone="deleted", status=UserStatus.DEACTIVATED,
        ),
    )


@router.put(
    "/reports/{report_id}/resolve",
    response_model=ResolveReportResponse,
    summary="Resolve a report (warn, ban, or dismiss)",
)
async def resolve_report(
    report_id: UUID,
    body: ResolveReportRequest,
    admin: AdminUser,
    db: DB,
):
    """
    Resolve a report with one of the following actions:
    - **warn**: Mark as reviewed, no further action
    - **ban**: Ban the reported user and close their matches
    - **dismiss**: Dismiss the report as unfounded
    """
    if body.action not in ("warn", "ban", "dismiss"):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Action must be one of: warn, ban, dismiss",
        )

    result = await db.execute(select(Report).where(Report.id == report_id))
    report = result.scalar_one_or_none()
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")

    if report.status != "pending":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Report already resolved with status: {report.status}",
        )

    now = datetime.now(timezone.utc)
    report.reviewed_by = admin.id
    report.reviewed_at = now

    if body.action == "dismiss":
        report.status = "dismissed"
        report.resolution = body.resolution_note or "Report dismissed by admin"
        resolution_msg = "Report dismissed"

    elif body.action == "warn":
        report.status = "reviewed"
        report.resolution = body.resolution_note or "Warning issued to reported user"
        resolution_msg = "Report reviewed, warning issued"

    elif body.action == "ban":
        report.status = "resolved"
        report.resolution = body.resolution_note or "Reported user banned"

        # Ban the reported user
        reported_result = await db.execute(
            select(User).where(User.id == report.reported_id)
        )
        reported_user = reported_result.scalar_one_or_none()
        if reported_user and reported_user.role != UserRole.ADMIN:
            reported_user.status = UserStatus.BANNED

            # Close their active matches
            matches_result = await db.execute(
                select(Match).where(
                    or_(
                        Match.sender_id == reported_user.id,
                        Match.receiver_id == reported_user.id,
                    ),
                    Match.status.in_([
                        MatchStatus.PENDING, MatchStatus.MUTUAL,
                        MatchStatus.APPROVED, MatchStatus.ACTIVE,
                    ]),
                )
            )
            for match in matches_result.scalars().all():
                match.status = MatchStatus.CLOSED
                match.closed_reason = "user_banned_via_report"

        resolution_msg = "Reported user banned and matches closed"

    await db.commit()

    return ResolveReportResponse(
        report_id=report.id,
        action=body.action,
        resolution=report.resolution or "",
        message=resolution_msg,
    )


# ─────────────────────────────────────────────
# FLAGGED MESSAGES
# ─────────────────────────────────────────────

@router.get(
    "/flagged-messages",
    response_model=FlaggedMessageListResponse,
    summary="Messages flagged by AI moderation",
)
async def list_flagged_messages(
    admin: AdminUser,
    db: DB,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
):
    """
    Returns messages that were flagged by the AI moderation system
    (moderation_passed = False or status = FLAGGED).
    """
    base_condition = or_(
        Message.moderation_passed == False,  # noqa: E712
        Message.status == MessageStatus.FLAGGED,
    )

    # Count
    count_result = await db.execute(
        select(func.count()).select_from(Message).where(base_condition)
    )
    total = count_result.scalar() or 0

    # Paginated query with sender phone
    offset = (page - 1) * page_size
    query = (
        select(Message, User.phone.label("sender_phone"))
        .join(User, User.id == Message.sender_id)
        .where(base_condition)
        .order_by(Message.created_at.desc())
        .offset(offset)
        .limit(page_size)
    )
    result = await db.execute(query)
    rows = result.all()

    messages = [
        FlaggedMessageResponse(
            id=msg.id,
            match_id=msg.match_id,
            sender_id=msg.sender_id,
            sender_phone=phone,
            content=msg.content,
            content_type=msg.content_type,
            moderation_reason=msg.moderation_reason,
            created_at=msg.created_at,
        )
        for msg, phone in rows
    ]

    return FlaggedMessageListResponse(
        messages=messages,
        total=total,
        page=page,
        page_size=page_size,
    )


# ─────────────────────────────────────────────
# MATCH MANAGEMENT
# ─────────────────────────────────────────────

@router.get(
    "/matches",
    response_model=AdminMatchListResponse,
    summary="List matches with filters",
)
async def list_matches(
    admin: AdminUser,
    db: DB,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    status_filter: Optional[MatchStatus] = Query(None, alias="status"),
    date_from: Optional[datetime] = Query(None, description="Filter matches created after this date"),
    date_to: Optional[datetime] = Query(None, description="Filter matches created before this date"),
):
    """
    List all matches with optional filters by status and date range.
    """
    conditions = []
    if status_filter:
        conditions.append(Match.status == status_filter)
    if date_from:
        conditions.append(Match.created_at >= date_from)
    if date_to:
        conditions.append(Match.created_at <= date_to)

    where_clause = and_(*conditions) if conditions else True

    # Count
    count_result = await db.execute(
        select(func.count()).select_from(Match).where(where_clause)
    )
    total = count_result.scalar() or 0

    # Paginated query with user phones
    offset = (page - 1) * page_size
    sender_user = User.__table__.alias("sender_user")
    receiver_user = User.__table__.alias("receiver_user")

    query = (
        select(
            Match,
            sender_user.c.phone.label("sender_phone"),
            receiver_user.c.phone.label("receiver_phone"),
        )
        .join(sender_user, sender_user.c.id == Match.sender_id)
        .join(receiver_user, receiver_user.c.id == Match.receiver_id)
        .where(where_clause)
        .order_by(Match.created_at.desc())
        .offset(offset)
        .limit(page_size)
    )
    result = await db.execute(query)
    rows = result.all()

    matches = [
        AdminMatchResponse(
            id=match.id,
            sender_id=match.sender_id,
            sender_phone=s_phone,
            receiver_id=match.receiver_id,
            receiver_phone=r_phone,
            status=match.status,
            compatibility_score=match.compatibility_score,
            created_at=match.created_at,
            became_mutual_at=match.became_mutual_at,
            nikah_date=match.nikah_date,
            closed_reason=match.closed_reason,
        )
        for match, s_phone, r_phone in rows
    ]

    return AdminMatchListResponse(
        matches=matches,
        total=total,
        page=page,
        page_size=page_size,
    )


@router.get(
    "/matches/stats",
    response_model=MatchFunnelStats,
    summary="Match funnel conversion stats",
)
async def get_match_stats(
    admin: AdminUser,
    db: DB,
):
    """
    Match funnel statistics showing conversion rates:
    pending -> mutual -> approved -> active -> nikah.
    """
    # Count each status
    counts_result = await db.execute(
        select(
            Match.status,
            func.count().label("count"),
        )
        .group_by(Match.status)
    )
    counts = {row.status: row.count for row in counts_result.all()}

    pending = counts.get(MatchStatus.PENDING, 0)
    mutual = counts.get(MatchStatus.MUTUAL, 0)
    approved = counts.get(MatchStatus.APPROVED, 0)
    active = counts.get(MatchStatus.ACTIVE, 0)
    nikah = counts.get(MatchStatus.NIKAH, 0)
    closed = counts.get(MatchStatus.CLOSED, 0)
    blocked = counts.get(MatchStatus.BLOCKED, 0)

    # Conversion rates (based on cumulative progression)
    total_ever_pending = pending + mutual + approved + active + nikah + closed + blocked
    total_ever_mutual = mutual + approved + active + nikah
    total_ever_active = active + nikah

    pending_to_mutual = (
        round((total_ever_mutual / total_ever_pending) * 100, 2)
        if total_ever_pending > 0 else 0.0
    )
    mutual_to_active = (
        round((total_ever_active / total_ever_mutual) * 100, 2)
        if total_ever_mutual > 0 else 0.0
    )
    active_to_nikah = (
        round((nikah / total_ever_active) * 100, 2)
        if total_ever_active > 0 else 0.0
    )

    return MatchFunnelStats(
        total_pending=pending,
        total_mutual=mutual,
        total_approved=approved,
        total_active=active,
        total_nikah=nikah,
        total_closed=closed,
        total_blocked=blocked,
        pending_to_mutual_rate=pending_to_mutual,
        mutual_to_active_rate=mutual_to_active,
        active_to_nikah_rate=active_to_nikah,
    )
