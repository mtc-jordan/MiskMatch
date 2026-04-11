import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/discovery_provider.dart';
import '../widgets/profile_card.dart';
import '../widgets/interest_sheet.dart';
import 'package:miskmatch/features/profile/providers/profile_provider.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/shared/widgets/common_widgets.dart';
import 'package:miskmatch/core/router/app_router.dart';
import 'package:go_router/go_router.dart';
import 'package:miskmatch/l10n/generated/app_localizations.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final _scrollCtrl = ScrollController();
  bool  _nudgeDismissed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(discoveryProvider.notifier).loadFeed();
      ref.read(profileProvider.notifier).load();
    });
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 400) {
      ref.read(discoveryProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(discoveryProvider);

    return Scaffold(
      backgroundColor: context.scaffoldColor,
      body: RefreshIndicator(
        color: AppColors.roseDeep,
        onRefresh: () async =>
            ref.read(discoveryProvider.notifier).refresh(),
        child: CustomScrollView(
          controller: _scrollCtrl,
          physics:    const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildAppBar(),
            _buildCompletionNudge(),

            // ── Feed header stat ────────────────────────────
            if (!feed.isLoading && !feed.isEmpty && feed.error == null)
              SliverToBoxAdapter(
                child: _FeedHeader(
                  count: feed.activeCandidates.length,
                ).animate().fadeIn(duration: 300.ms),
              ),

            // ── Feed content ────────────────────────────────
            if (feed.isLoading)
              _buildShimmer()
            else if (feed.error != null)
              SliverToBoxAdapter(child: _buildError(feed.error!.message))
            else if (feed.isEmpty)
              const SliverToBoxAdapter(child: _EmptyState())
            else
              _buildFeedList(feed),

            // ── Loading more ────────────────────────────────
            if (feed.isLoadingMore)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: SizedBox(
                      width: 28, height: 28,
                      child: CircularProgressIndicator(
                        color: AppColors.roseDeep, strokeWidth: 2),
                    ),
                  ),
                ),
              ),

            const SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.bottomNavHeight + 16)),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // APP BAR
  // ─────────────────────────────────────────────

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      floating:  true,
      snap:      true,
      backgroundColor:       context.scaffoldColor,
      elevation:             0,
      scrolledUnderElevation: 0,
      surfaceTintColor:      Colors.transparent,
      title: Row(
        children: [
          // مـ rose circle 36px with subtle glow
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              gradient: AppColors.roseGradient,
              shape:    BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color:      AppColors.roseDeep.withOpacity(0.25),
                  blurRadius: 10,
                  offset:     const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Text('مـ',
                style: TextStyle(
                  fontFamily:  'Scheherazade',
                  fontSize:    16,
                  color:       AppColors.white,
                  fontWeight:  FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(S.of(context).discover,
            style: const TextStyle(
              fontFamily:  'Georgia',
              fontSize:    22,
              fontWeight:  FontWeight.w700,
              color:       AppColors.roseDeep,
            ),
          ),
        ],
      ),
      actions: [
        // Filter button with dot
        Stack(
          children: [
            IconButton(
              icon:      const Icon(Icons.tune_rounded, size: 22),
              color:     context.mutedText,
              tooltip:   'Filter profiles',
              onPressed: () {},
            ),
            Positioned(
              top: 10, right: 10,
              child: Container(
                width: 7, height: 7,
                decoration: const BoxDecoration(
                  color: AppColors.roseDeep,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        IconButton(
          icon:      const Icon(Icons.refresh_rounded, size: 22),
          color:     context.mutedText,
          tooltip:   'Refresh feed',
          onPressed: () {
            HapticFeedback.lightImpact();
            ref.read(discoveryProvider.notifier).refresh();
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // COMPLETION NUDGE — modern gradient card
  // ─────────────────────────────────────────────

  Widget _buildCompletionNudge() {
    if (_nudgeDismissed) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final completionAsync = ref.watch(profileCompletionProvider);
    return SliverToBoxAdapter(
      child: completionAsync.when(
        loading: () => const SizedBox.shrink(),
        error:   (_, __) => const SizedBox.shrink(),
        data: (c) {
          if (c.percentage >= 80) return const SizedBox.shrink();
          return Semantics(
            button: true,
            label: 'Profile ${c.percentage} percent complete, tap to continue editing',
            child: GestureDetector(
              onTap: () => context.push(AppRoutes.profileEdit),
              child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppColors.goldPrimary.withOpacity(0.12),
                  AppColors.goldLight.withOpacity(0.06),
                ]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.goldPrimary.withOpacity(0.20)),
              ),
              child: Row(
                children: [
                  // Animated progress ring
                  SizedBox(
                    width: 36, height: 36,
                    child: TweenAnimationBuilder<double>(
                      tween:    Tween(begin: 0, end: c.percentage / 100),
                      duration: 800.ms,
                      curve:    Curves.easeOutCubic,
                      builder: (_, value, __) => Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value:           value,
                            strokeWidth:     3.5,
                            backgroundColor:
                                AppColors.goldPrimary.withOpacity(0.12),
                            valueColor: const AlwaysStoppedAnimation(
                                AppColors.goldPrimary),
                          ),
                          Text('${c.percentage}',
                            style: AppTypography.labelSmall.copyWith(
                              color:      AppColors.goldPrimary,
                              fontSize:   10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          S.of(context).completeProfileMoreMatches,
                          style: AppTypography.labelMedium.copyWith(
                            color:      AppColors.goldDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${c.missingFields.length} fields remaining',
                          style: AppTypography.labelSmall.copyWith(
                            color:    AppColors.goldPrimary.withOpacity(0.7),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _nudgeDismissed = true),
                    child: Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.goldPrimary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: AppColors.goldPrimary, size: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
              )
              .animate()
              .slideY(begin: -0.3, end: 0, duration: 400.ms,
                      curve: Curves.easeOutCubic)
              .fadeIn(duration: 300.ms);
        },
      ),
    );
  }

  // ─────────────────────────────────────────────
  // FEED LIST
  // ─────────────────────────────────────────────

  SliverList _buildFeedList(DiscoveryFeedState feed) {
    final candidates = feed.activeCandidates;
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, i) {
          final candidate = candidates[i];
          final profile   = candidate.profile;

          if (feed.expressedInterest.contains(profile.userId)) {
            return _InterestSentCard(name: profile.displayFirstName)
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.05, end: 0, duration: 400.ms);
          }

          return ProfileCard(
            candidate: candidate,
            index:     i,
            onInterest: () async {
              final sent =
                  await showInterestSheet(context, profile, ref);
              if (sent == true && context.mounted) {
                HapticFeedback.heavyImpact();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      'Interest sent to ${profile.displayFirstName}. '
                      'JazakAllah Khair 🌙'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppColors.success,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                ));
              }
            },
            onDismiss: () {
              HapticFeedback.lightImpact();
              ref.read(discoveryProvider.notifier)
                  .dismiss(profile.userId);
            },
            onExpand: () {},
          );
        },
        childCount: candidates.length,
      ),
    );
  }

  // ─────────────────────────────────────────────
  // SHIMMER — 2 skeleton cards
  // ─────────────────────────────────────────────

  SliverList _buildShimmer() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, i) => _ShimmerCard(index: i),
        childCount: 2,
      ),
    );
  }

  // ─────────────────────────────────────────────
  // ERROR STATE
  // ─────────────────────────────────────────────

  Widget _buildError(String message) => Padding(
    padding: const EdgeInsets.all(40),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.wifi_off_rounded,
              size: 32, color: context.mutedText),
        ),
        const SizedBox(height: 20),
        Text(message,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
                color: context.mutedText)),
        const SizedBox(height: 24),
        MiskButton(
          label:     S.of(context).tryAgain,
          onPressed: () => ref.read(discoveryProvider.notifier).refresh(),
          variant:   MiskButtonVariant.outline,
          fullWidth: false,
          icon:      Icons.refresh_rounded,
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────
// FEED HEADER — "N candidates for you"
// ─────────────────────────────────────────────

class _FeedHeader extends StatelessWidget {
  const _FeedHeader({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          Container(
            width: 6, height: 6,
            decoration: const BoxDecoration(
              color: AppColors.roseDeep,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count candidate${count == 1 ? '' : 's'} for you',
            style: AppTypography.labelMedium.copyWith(
              color:         context.mutedText,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          Text(
            S.of(context).sortedByCompatibility,
            style: AppTypography.labelSmall.copyWith(
              color:    context.mutedText.withOpacity(0.6),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// INTEREST SENT CARD
// ─────────────────────────────────────────────

class _InterestSentCard extends StatelessWidget {
  const _InterestSentCard({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppColors.success.withOpacity(0.08),
          AppColors.success.withOpacity(0.03),
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.success.withOpacity(0.25)),
      ),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded,
              color: AppColors.success, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Interest sent to $name',
                style: AppTypography.labelMedium.copyWith(
                  color:      AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                S.of(context).mayAllahMakeItKhayr,
                style: AppTypography.labelSmall.copyWith(
                  color:    AppColors.success.withOpacity(0.7),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// SHIMMER SKELETON CARD — matches new card shape
// ─────────────────────────────────────────────

class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color:        context.surfaceColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow:    context.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo shimmer — 3:4 like the card
            AspectRatio(
              aspectRatio: 3 / 4,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end:   Alignment.bottomRight,
                    colors: [
                      context.subtleBg,
                      context.subtleBg.withOpacity(0.6),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Frosted name bar placeholder
                    Positioned(
                      left: 16, right: 16, bottom: 16,
                      child: Container(
                        height: 80,
                        decoration: BoxDecoration(
                          color: context.subtleBg.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content shimmer bars
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Islamic practice bar
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color:        context.subtleBg.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Pills
                  Row(children: [
                    _shimmerPill(context, 80),
                    const SizedBox(width: 8),
                    _shimmerPill(context, 60),
                    const SizedBox(width: 8),
                    _shimmerPill(context, 90),
                  ]),
                  const SizedBox(height: 14),
                  // Bio lines
                  _shimmerBar(context, width: 1.0),
                  const SizedBox(height: 8),
                  _shimmerBar(context, width: 0.85),
                  const SizedBox(height: 8),
                  _shimmerBar(context, width: 0.6),
                  const SizedBox(height: 18),
                  // Action row
                  Row(children: [
                    Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        color: context.subtleBg,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        color: context.subtleBg,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color:        context.subtleBg,
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(
          duration: 1200.ms,
          color:    Colors.white.withOpacity(0.3),
        );
  }

  Widget _shimmerBar(BuildContext context, {required double width}) {
    return FractionallySizedBox(
      alignment:  Alignment.centerLeft,
      widthFactor: width,
      child: Container(
        height: 10,
        decoration: BoxDecoration(
          color:        context.subtleBg,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _shimmerPill(BuildContext context, double width) {
    return Container(
      width: width, height: 28,
      decoration: BoxDecoration(
        color:        context.subtleBg.withOpacity(0.6),
        borderRadius: BorderRadius.circular(100),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// EMPTY STATE — elegant, spiritual
// ─────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 80, 40, 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated crescent with glow
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.goldPrimary.withOpacity(0.12),
                  Colors.transparent,
                ],
              ),
            ),
            child: const Center(
              child: Text('🌙', style: TextStyle(fontSize: 56)),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 0.92, end: 1.08, duration: 2500.ms,
                       curve: Curves.easeInOut),

          const SizedBox(height: 28),

          Text(S.of(context).noMoreCandidates,
            style: TextStyle(
              fontFamily:  'Georgia',
              fontSize:    26,
              fontWeight:  FontWeight.w700,
              color:       context.subtleText,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 20),

          // Arabic ayah in a styled container
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.goldPrimary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.goldPrimary.withOpacity(0.15)),
            ),
            child: Column(
              children: [
                const ArabicText(
                  'إِنَّ اللَّهَ لَا يُضِيعُ أَجْرَ الْمُحْسِنِينَ',
                  style: TextStyle(
                    fontFamily: 'Scheherazade',
                    fontSize:   20,
                    color:      AppColors.goldPrimary,
                    height:     2.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '"Indeed, Allah does not allow the reward '
                  'of the doers of good to be lost."',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(
                    color:     context.mutedText,
                    fontStyle: FontStyle.italic,
                    fontSize:  11,
                    height:    1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'Complete your profile to start receiving\n'
            'compatible matches, in sha Allah.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color:  context.mutedText,
              height: 1.6,
            ),
          ),
        ],
      ).animate().fadeIn(duration: 600.ms)
          .slideY(begin: 0.08, end: 0, duration: 500.ms,
                  curve: Curves.easeOutCubic),
    );
  }
}
