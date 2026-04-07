import 'package:flutter/material.dart';
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

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final _scrollCtrl = ScrollController();

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
    final feed  = ref.watch(discoveryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        controller: _scrollCtrl,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          _buildAppBar(context),
          _buildCompletionNudge(),
          if (feed.isLoading)
            _buildShimmer()
          else if (feed.error != null)
            SliverToBoxAdapter(child: _buildError(feed.error!.message))
          else if (feed.isEmpty)
            const SliverToBoxAdapter(child: _EmptyState())
          else
            _buildFeedList(feed),
          if (feed.isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(
                      color: AppColors.roseDeep, strokeWidth: 2),
                ),
              ),
            ),
          const SliverToBoxAdapter(
              child: SizedBox(height: AppSpacing.bottomNavHeight + 16)),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context) {
    return SliverAppBar(
      floating: true,
      snap:     true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      scrolledUnderElevation: 1,
      surfaceTintColor: Colors.transparent,
      title: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: const BoxDecoration(
              gradient: AppColors.roseGradient,
              shape:    BoxShape.circle,
            ),
            child: const Center(
              child: Text('مـ',
                  style: TextStyle(
                    fontFamily: 'Scheherazade',
                    fontSize: 16, color: AppColors.white,
                    fontWeight: FontWeight.w700,
                  )),
            ),
          ),
          const SizedBox(width: 10),
          Text('Discover',
              style: AppTypography.titleLarge.copyWith(
                color: AppColors.roseDeep, fontWeight: FontWeight.w700)),
        ],
      ),
      actions: [
        IconButton(
          icon:      const Icon(Icons.refresh_rounded),
          color:     AppColors.neutral500,
          onPressed: () => ref.read(discoveryProvider.notifier).refresh(),
        ),
        IconButton(
          icon:      const Icon(Icons.tune_rounded),
          color:     AppColors.neutral500,
          onPressed: () {},
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildCompletionNudge() {
    final completionAsync = ref.watch(profileCompletionProvider);
    return SliverToBoxAdapter(
      child: completionAsync.when(
        loading: () => const SizedBox.shrink(),
        error:   (_, __) => const SizedBox.shrink(),
        data: (c) {
          if (c.percentage >= 80) return const SizedBox.shrink();
          return Container(
            margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppColors.goldPrimary.withOpacity(0.12),
                AppColors.roseDeep.withOpacity(0.06),
              ]),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.goldPrimary.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_outline_rounded,
                    color: AppColors.goldPrimary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Complete your profile — ${c.percentage}% done',
                          style: AppTypography.labelMedium.copyWith(
                            color: AppColors.goldDark)),
                      Text('A complete profile gets 3× more interest.',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.goldDark.withOpacity(0.7))),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.goldPrimary),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms);
        },
      ),
    );
  }

  SliverList _buildFeedList(DiscoveryFeedState feed) {
    final candidates = feed.activeCandidates;
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, i) {
          final candidate = candidates[i];
          final profile   = candidate.profile;
          if (feed.expressedInterest.contains(profile.userId)) {
            return Container(
              margin: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPadding, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:        AppColors.success.withOpacity(0.08),
                borderRadius: AppRadius.cardRadius,
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Interest sent to ${profile.displayFirstName} 🤲',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.success),
                ),
              ]),
            );
          }
          return ProfileCard(
            candidate:  candidate,
            index:      i,
            onInterest: () async {
              final sent = await showInterestSheet(context, profile, ref);
              if (sent == true && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      'Interest sent to ${profile.displayFirstName}. JazakAllah Khair 🌙'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppColors.success,
                ));
              }
            },
            onDismiss: () =>
                ref.read(discoveryProvider.notifier).dismiss(profile.userId),
            onExpand: () {},
          );
        },
        childCount: candidates.length,
      ),
    );
  }

  SliverList _buildShimmer() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, i) => Container(
          margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding, vertical: 8),
          height: 340,
          decoration: BoxDecoration(
            color:        Theme.of(context).colorScheme.surface,
            borderRadius: AppRadius.cardRadius,
            boxShadow:    AppShadows.card,
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .shimmer(duration: 1200.ms,
                color: AppColors.roseLight.withOpacity(0.3)),
        childCount: 3,
      ),
    );
  }

  Widget _buildError(String message) => Padding(
    padding: const EdgeInsets.all(40),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.neutral300),
        const SizedBox(height: 20),
        Text(message,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.neutral500)),
        const SizedBox(height: 24),
        MiskButton(
          label:     'Try again',
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
// EMPTY STATE
// ─────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 60, 40, 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🌙', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 24),
          Text('No candidates yet',
              style: AppTypography.headlineSmall.copyWith(
                  color: AppColors.neutral700),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(
            'Complete your profile to start receiving '
            'compatible matches. Our AI engine will find '
            'those who align with your values, in sha Allah.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
                color: AppColors.neutral500, height: 1.6),
          ),
          const SizedBox(height: 16),
          const ArabicText(
            'إِنَّ اللَّهَ لَا يُضِيعُ أَجْرَ الْمُحْسِنِينَ',
            style: TextStyle(
              fontFamily: 'Scheherazade',
              fontSize:   16,
              color:      AppColors.goldPrimary,
              height:     2.0,
            ),
          ),
        ],
      ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0),
    );
  }
}
