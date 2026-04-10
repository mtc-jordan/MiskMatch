import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/match_models.dart';
import '../providers/match_provider.dart';
import '../widgets/wali_status_card.dart';
import '../widgets/match_timeline_card.dart';
import 'package:miskmatch/features/auth/providers/auth_provider.dart';
import 'package:miskmatch/features/calls/widgets/call_schedule_sheet.dart';
import 'package:miskmatch/features/discovery/widgets/voice_player.dart';
import 'package:miskmatch/core/router/app_router.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/shared/widgets/common_widgets.dart';

class MatchScreen extends ConsumerWidget {
  const MatchScreen({super.key, required this.matchId});
  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchAsync = ref.watch(matchDetailProvider(matchId));
    final auth       = ref.read(authProvider);
    final myUserId   = auth is AuthAuthenticated ? auth.userId : '';

    return Scaffold(
      backgroundColor: context.scaffoldColor,
      body: matchAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
              color: AppColors.roseDeep, strokeWidth: 2),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 48, color: AppColors.neutral300),
                const SizedBox(height: 16),
                Text('$e',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                    color: context.mutedText),
                ),
                const SizedBox(height: 20),
                MiskButton(
                  label:     'Retry',
                  onPressed: () =>
                      ref.refresh(matchDetailProvider(matchId)),
                  fullWidth: false,
                  variant:   MiskButtonVariant.outline,
                ),
              ],
            ),
          ),
        ),
        data: (match) {
          final other = match.otherProfile(myUserId);
          final name  = other?.displayFirstName ?? 'Match';

          return CustomScrollView(
            slivers: [
              // ── App bar ──────────────────────────────────────
              SliverAppBar(
                pinned: true,
                backgroundColor: context.scaffoldColor,
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                leading: const BackButton(),
                title: Text(name,
                  style: const TextStyle(
                    fontFamily:  'Georgia',
                    fontSize:    22,
                    fontWeight:  FontWeight.w700,
                    color:       AppColors.roseDeep,
                  ),
                ),
                actions: [
                  // Status chip
                  Container(
                    margin: const EdgeInsets.only(
                        right: 16, top: 10, bottom: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: match.status.canChat
                          ? AppColors.success.withOpacity(0.12)
                          : AppColors.goldPrimary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      match.status.canChat
                          ? 'Active'
                          : 'Awaiting families',
                      style: AppTypography.labelSmall.copyWith(
                        color: match.status.canChat
                            ? AppColors.success
                            : AppColors.goldDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              // ── Content ──────────────────────────────────────
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── PROFILE CARD ───────────────────────────
                    _ProfileCard(
                      match: match,
                      other: other,
                    ).animate().fadeIn(duration: 400.ms),

                    const SizedBox(height: 14),

                    // ── WALI STATUS CARD ───────────────────────
                    WaliStatusCard(
                      match:    match,
                      myUserId: myUserId,
                    ).animate(delay: 100.ms).fadeIn(duration: 400.ms),

                    const SizedBox(height: 14),

                    // ── QUICK ACTIONS ──────────────────────────
                    _QuickActions(
                      match:     match,
                      matchId:   matchId,
                      otherName: name,
                    ).animate(delay: 150.ms).fadeIn(duration: 400.ms),

                    // ── COMPATIBILITY CARD ─────────────────────
                    if (match.compatibilityScore != null) ...[
                      const SizedBox(height: 14),
                      _CompatibilityCard(match: match)
                          .animate(delay: 200.ms)
                          .fadeIn(duration: 400.ms),
                    ],

                    // ── MEMORY TIMELINE ────────────────────────
                    if (match.memoryTimeline.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      MatchTimelineCard(timeline: match.memoryTimeline)
                          .animate(delay: 250.ms)
                          .fadeIn(duration: 400.ms),
                    ],

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PROFILE CARD
// ─────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.match,
    required this.other,
  });
  final Match        match;
  final dynamic      other; // UserProfile?

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:        context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow:    context.cardShadow,
      ),
      child: Column(
        children: [
          // ── Row: avatar + info + compat ring ────────────────
          Row(
            children: [
              // 80px avatar
              Hero(
                tag: 'match_avatar_${match.id}',
                child: Container(
                  width: 80, height: 80,
                  decoration: const BoxDecoration(
                    gradient: AppColors.roseGradient,
                    shape:    BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      other?.firstName?.isNotEmpty == true
                          ? other!.firstName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize:   36,
                        color:      AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // Name + age + location + trust
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + age
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: other?.displayFirstName ?? 'Match',
                            style: TextStyle(
                              fontFamily:  'Georgia',
                              fontSize:    20,
                              fontWeight:  FontWeight.w700,
                              color:       context.onSurface,
                            ),
                          ),
                          if (other?.age != null)
                            TextSpan(
                              text: ', ${other!.age}',
                              style: TextStyle(
                                fontFamily: 'Georgia',
                                fontSize:   20,
                                color:      context.mutedText,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Location
                    if (other?.locationText?.isNotEmpty == true) ...[
                      const SizedBox(height: 3),
                      Row(children: [
                        const Text('📍',
                            style: TextStyle(fontSize: 11)),
                        const SizedBox(width: 3),
                        Text(other!.locationText,
                          style: AppTypography.bodySmall.copyWith(
                            color:    context.mutedText,
                            fontSize: 13,
                          ),
                        ),
                      ]),
                    ],

                    // Trust badges
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, children: [
                      if (other?.mosqueVerified == true)
                        const TrustBadge(type: TrustBadgeType.mosque),
                      if (other?.scholarEndorsed == true)
                        const TrustBadge(type: TrustBadgeType.scholar),
                      if (other?.idVerified == true)
                        const TrustBadge(type: TrustBadgeType.identity),
                    ]),
                  ],
                ),
              ),

              // 68px CompatibilityRing
              if (match.compatibilityScore != null)
                CompatibilityRing(
                  score: match.compatibilityScore!,
                  size:  68,
                ),
            ],
          ),

          // ── Voice intro player ──────────────────────────────
          if (other?.hasVoiceIntro == true) ...[
            const SizedBox(height: 14),
            VoicePlayerWidget(
              audioUrl: other!.voiceIntroUrl!,
              label: "Hear ${other.displayFirstName}'s intro",
            ),
          ],

          // ── Match day badge ─────────────────────────────────
          if (match.matchDay > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.roseDeep.withOpacity(0.06),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 14, color: AppColors.roseDeep),
                  const SizedBox(width: 6),
                  Text(
                    'Day ${match.matchDay}',
                    style: AppTypography.labelSmall.copyWith(
                      color:      AppColors.roseDeep,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// QUICK ACTIONS
// ─────────────────────────────────────────────

class _QuickActions extends ConsumerWidget {
  const _QuickActions({
    required this.match,
    required this.matchId,
    required this.otherName,
  });
  final Match  match;
  final String matchId;
  final String otherName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(children: [
            // Chat button — rose
            Expanded(
              child: MiskButton(
                label:     'Chat',
                onPressed: match.status.canChat
                    ? () => context.push(AppRoutes.chatPath(matchId))
                    : null,
                icon: Icons.chat_bubble_outline_rounded,
              ),
            ),
            const SizedBox(width: 12),
            // Games button — outline
            Expanded(
              child: MiskButton(
                label:     'Games',
                onPressed: match.status.canPlayGames
                    ? () => context.push(
                        AppRoutes.gameHubPath(matchId))
                    : null,
                variant: MiskButtonVariant.outline,
                icon:    Icons.games_outlined,
              ),
            ),
          ]),

          const SizedBox(height: 10),

          // Chaperoned call — gold, full width
          MiskButton(
            label:     '🛡️ Chaperoned Call',
            onPressed: match.status.canChat
                ? () {
                    showCallScheduleSheet(
                      context:   context,
                      ref:       ref,
                      matchId:   matchId,
                      myName:    'Me',
                      otherName: otherName,
                    );
                  }
                : null,
            variant: MiskButtonVariant.gold,
            icon:    Icons.videocam_rounded,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// COMPATIBILITY CARD — rose bg, 4 breakdown bars
// ─────────────────────────────────────────────

class _CompatibilityCard extends StatelessWidget {
  const _CompatibilityCard({required this.match});
  final Match match;

  String get _tierLabel {
    final s = match.compatibilityScore!;
    if (s >= 85) return 'Exceptional';
    if (s >= 72) return 'Strong';
    if (s >= 58) return 'Good';
    if (s >= 42) return 'Moderate';
    return 'Low';
  }

  Color get _tierColor {
    final s = match.compatibilityScore!;
    if (s >= 85) return AppColors.compatExceptional;
    if (s >= 72) return AppColors.compatStrong;
    if (s >= 58) return AppColors.compatGood;
    if (s >= 42) return AppColors.compatModerate;
    return AppColors.compatLow;
  }

  @override
  Widget build(BuildContext context) {
    final score = match.compatibilityScore!;
    final breakdown = match.compatibilityBreakdown;

    return Container(
      margin:  const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:        AppColors.roseDeep.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title: "X% Compatibility · tier"
          Text(
            '${score.round()}% Compatibility · $_tierLabel',
            style: TextStyle(
              fontFamily:  'Georgia',
              fontSize:    16,
              fontWeight:  FontWeight.w700,
              color:       _tierColor,
            ),
          ),

          const SizedBox(height: 14),

          // Main progress bar — animated 600ms
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween:    Tween(begin: 0, end: score / 100),
              duration: 600.ms,
              curve:    Curves.easeOutCubic,
              builder: (_, value, __) => LinearProgressIndicator(
                value:           value,
                backgroundColor: AppColors.roseDeep.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation(_tierColor),
                minHeight: 8,
              ),
            ),
          ),

          const SizedBox(height: 18),

          // 4 breakdown bars
          if (breakdown != null) ...[
            _BreakdownBar(
              label: 'Deen',
              score: (breakdown['deen'] as num?)?.toDouble() ?? 0,
            ),
            const SizedBox(height: 10),
            _BreakdownBar(
              label: 'Life Goals',
              score: (breakdown['life_goals'] as num?)?.toDouble() ?? 0,
            ),
            const SizedBox(height: 10),
            _BreakdownBar(
              label: 'Personality',
              score: (breakdown['personality'] as num?)?.toDouble() ?? 0,
            ),
            const SizedBox(height: 10),
            _BreakdownBar(
              label: 'Practical',
              score: (breakdown['practical'] as num?)?.toDouble() ?? 0,
            ),
          ],
        ],
      ),
    );
  }
}

class _BreakdownBar extends StatelessWidget {
  const _BreakdownBar({required this.label, required this.score});
  final String label;
  final double score;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label,
            style: AppTypography.labelSmall.copyWith(
              color: context.subtleText),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: TweenAnimationBuilder<double>(
              tween:    Tween(begin: 0, end: score / 100),
              duration: 800.ms,
              curve:    Curves.easeOutCubic,
              builder: (_, value, __) => LinearProgressIndicator(
                value:           value,
                backgroundColor: AppColors.roseDeep.withOpacity(0.08),
                valueColor: const AlwaysStoppedAnimation(AppColors.roseDeep),
                minHeight: 6,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 32,
          child: Text('${score.round()}%',
            textAlign: TextAlign.right,
            style: AppTypography.labelSmall.copyWith(
              color:      AppColors.roseDeep,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
