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
import 'package:miskmatch/features/calls/data/call_models.dart';
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: matchAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.roseDeep)),
        error: (e, _) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$e'),
            const SizedBox(height: 16),
            MiskButton(label: 'Retry', onPressed: () => ref.refresh(matchDetailProvider(matchId)), fullWidth: false),
          ]),
        ),
        data: (match) {
          final other = match.otherProfile(myUserId);
          return CustomScrollView(slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              elevation: 0,
              leading: const BackButton(),
              title: Text(other?.displayFirstName ?? 'Match',
                  style: AppTypography.titleLarge.copyWith(color: AppColors.roseDeep, fontWeight: FontWeight.w700)),
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: match.status.canChat ? AppColors.success.withOpacity(0.12) : AppColors.goldPrimary.withOpacity(0.12),
                    borderRadius: AppRadius.chipRadius,
                  ),
                  child: Text(match.status.label,
                      style: AppTypography.labelSmall.copyWith(
                        color: match.status.canChat ? AppColors.success : AppColors.goldDark,
                        fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // Profile card
                MiskCard(
                  margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(children: [
                    Row(children: [
                      Container(
                        width: 72, height: 72,
                        decoration: const BoxDecoration(gradient: AppColors.roseGradient, shape: BoxShape.circle),
                        child: Center(child: Text(
                          other?.firstName.isNotEmpty == true ? other!.firstName[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 32, color: AppColors.white, fontWeight: FontWeight.w700),
                        )),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${other?.displayFirstName ?? 'Match'}${other?.age != null ? ', ${other!.age}' : ''}',
                            style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w700)),
                        if (other?.locationText.isNotEmpty == true)
                          Row(children: [
                            const Icon(Icons.location_on_outlined, size: 13, color: AppColors.neutral500),
                            const SizedBox(width: 3),
                            Text(other!.locationText, style: AppTypography.bodySmall.copyWith(color: AppColors.neutral500)),
                          ]),
                        const SizedBox(height: 6),
                        Wrap(spacing: 6, children: [
                          if (other?.mosqueVerified == true) const TrustBadge(type: TrustBadgeType.mosque),
                          if (other?.scholarEndorsed == true) const TrustBadge(type: TrustBadgeType.scholar),
                        ]),
                      ])),
                      if (match.compatibilityScore != null)
                        CompatibilityRing(score: match.compatibilityScore!, size: 64),
                    ]),
                    if (other?.hasVoiceIntro == true) ...[
                      const SizedBox(height: 14),
                      VoicePlayerWidget(audioUrl: other!.voiceIntroUrl!, label: "Hear ${other.displayFirstName}'s voice intro"),
                    ],
                    if (match.matchDay > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: AppColors.roseDeep.withOpacity(0.06), borderRadius: AppRadius.chipRadius),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.roseDeep),
                          const SizedBox(width: 6),
                          Text('Day ${match.matchDay}',
                              style: AppTypography.labelSmall.copyWith(color: AppColors.roseDeep)),
                        ]),
                      ),
                    ],
                  ]),
                ).animate().fadeIn(duration: 400.ms),

                const SizedBox(height: 14),
                WaliStatusCard(match: match, myUserId: myUserId).animate(delay: 100.ms).fadeIn(),

                const SizedBox(height: 14),
                // Quick actions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(children: [
                    Row(children: [
                      Expanded(child: MiskButton(
                        label: 'Chat',
                        onPressed: match.status.canChat ? () => context.push(AppRoutes.chatPath(matchId)) : null,
                        icon: Icons.chat_bubble_outline_rounded,
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: MiskButton(
                        label: 'Games',
                        onPressed: match.status.canPlayGames ? () => context.push(AppRoutes.gameHubPath(matchId)) : null,
                        variant: MiskButtonVariant.outline,
                        icon: Icons.games_outlined,
                      )),
                    ]),
                    const SizedBox(height: 10),
                    MiskButton(
                      label:    '🛡️ Chaperoned Call',
                      onPressed: match.status.canChat ? () {
                        showCallScheduleSheet(
                          context:   context,
                          ref:       ref,
                          matchId:   matchId,
                          myName:    'Me',
                          otherName: other?.displayFirstName ?? 'Match',
                        );
                      } : null,
                      variant: MiskButtonVariant.gold,
                      icon:    Icons.videocam_rounded,
                    ),
                  ]),
                ).animate(delay: 150.ms).fadeIn(),

                if (match.compatibilityScore != null) ...[
                  const SizedBox(height: 14),
                  MiskCard(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.favorite_rounded, color: AppColors.roseDeep, size: 18),
                        const SizedBox(width: 8),
                        Text('${match.compatibilityScore!.round()}% Compatibility',
                            style: AppTypography.titleSmall.copyWith(color: AppColors.roseDeep)),
                      ]),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: match.compatibilityScore! / 100,
                        backgroundColor: AppColors.roseLight.withOpacity(0.3),
                        valueColor: const AlwaysStoppedAnimation(AppColors.roseDeep),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ]),
                  ).animate(delay: 200.ms).fadeIn(),
                ],

                if (match.memoryTimeline.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  MatchTimelineCard(timeline: match.memoryTimeline).animate(delay: 250.ms).fadeIn(),
                ],

                const SizedBox(height: 80),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}
