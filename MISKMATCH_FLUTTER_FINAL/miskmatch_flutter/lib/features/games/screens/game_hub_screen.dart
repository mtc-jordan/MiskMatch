import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/game_models.dart';
import '../providers/game_providers.dart';
import '../widgets/game_card.dart';
import 'package:miskmatch/core/router/app_router.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/shared/widgets/common_widgets.dart';

class GameHubScreen extends ConsumerWidget {
  const GameHubScreen({super.key, required this.matchId});
  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogueAsync = ref.watch(gameCatalogueProvider(matchId));
    final timelineAsync  = ref.watch(memoryTimelineProvider(matchId));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ────────────────────────────────────────────────
          SliverAppBar(
            pinned:          true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation:       0,
            leading:         const BackButton(),
            title:           Text('Games',
                style: AppTypography.titleLarge.copyWith(
                    color: AppColors.roseDeep, fontWeight: FontWeight.w700)),
            actions: [
              IconButton(
                icon:    const Icon(Icons.history_rounded),
                tooltip: 'Match Memory',
                onPressed: () {
                  _showMemoryTimeline(context, timelineAsync);
                },
              ),
            ],
          ),

          // ── Catalogue content ──────────────────────────────────────
          catalogueAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(
                  color: AppColors.roseDeep, strokeWidth: 2)),
            ),
            error: (e, _) => SliverFillRemaining(
              child: _ErrorState(
                message:  e.toString(),
                onRetry: () => ref.refresh(gameCatalogueProvider(matchId)),
              ),
            ),
            data: (catalogue) => SliverList(
              delegate: SliverChildListDelegate([
                // Match day + progress header
                _MatchDayHeader(catalogue: catalogue)
                    .animate().fadeIn(duration: 400.ms),

                // My turn nudge
                if (catalogue.myTurnGames.isNotEmpty)
                  _MyTurnNudge(
                    games:   catalogue.myTurnGames,
                    matchId: matchId,
                  ).animate(delay: 100.ms).fadeIn(),

                // Categories
                ...catalogue.categories.entries.indexed.map((entry) {
                  final i    = entry.$1;
                  final cat  = entry.$2;
                  final games= cat.value;
                  if (games.isEmpty) return const SizedBox.shrink();
                  return _CategorySection(
                    category: GameCategory.fromValue(cat.key),
                    games:    games,
                    matchId:  matchId,
                    sectionIndex: i,
                  ).animate(delay: Duration(milliseconds: 150 + i * 60))
                   .fadeIn(duration: 400.ms);
                }),

                const SizedBox(height: AppSpacing.bottomNavHeight + 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showMemoryTimeline(
    BuildContext context,
    AsyncValue<MemoryTimeline> timelineAsync,
  ) {
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => _MemoryTimelineSheet(timelineAsync: timelineAsync),
    );
  }
}

// ─────────────────────────────────────────────
// MATCH DAY HEADER
// ─────────────────────────────────────────────

class _MatchDayHeader extends StatelessWidget {
  const _MatchDayHeader({required this.catalogue});
  final GameCatalogue catalogue;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppColors.roseDeep.withOpacity(0.07),
          AppColors.goldPrimary.withOpacity(0.04),
        ]),
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.roseDeep.withOpacity(0.1)),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Day ${catalogue.matchDay}',
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.roseDeep, fontWeight: FontWeight.w700)),
          Text(
            '${catalogue.totalUnlocked} of ${catalogue.totalGames} games unlocked',
            style: AppTypography.bodySmall.copyWith(color: AppColors.neutral500),
          ),
        ])),
        // Unlock progress ring
        SizedBox(
          width: 52, height: 52,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(
              value:       catalogue.totalUnlocked / catalogue.totalGames,
              strokeWidth: 5,
              color:       AppColors.roseDeep,
              backgroundColor: AppColors.roseLight.withOpacity(0.3),
              strokeCap:   StrokeCap.round,
            ),
            Text('${catalogue.totalUnlocked}',
                style: AppTypography.titleSmall.copyWith(
                  color:      AppColors.roseDeep,
                  fontWeight: FontWeight.w700,
                  fontSize:   16,
                )),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// MY TURN NUDGE
// ─────────────────────────────────────────────

class _MyTurnNudge extends StatelessWidget {
  const _MyTurnNudge({required this.games, required this.matchId});
  final List<GameMeta> games;
  final String         matchId;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.fromLTRB(20, 0, 20, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient:     AppColors.roseGradient,
        borderRadius: AppRadius.cardRadius,
        boxShadow:    AppShadows.elevated,
      ),
      child: Row(children: [
        const Text('🎮', style: TextStyle(fontSize: 24)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            games.length == 1
                ? "It's your turn in ${games.first.name}!"
                : "It's your turn in ${games.length} games!",
            style: AppTypography.titleSmall.copyWith(color: AppColors.white),
          ),
          Text('Tap a game below to respond.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.white.withOpacity(0.8))),
        ])),
        const Icon(Icons.chevron_right_rounded, color: AppColors.white),
      ]),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(duration: 2000.ms,
            color: AppColors.white.withOpacity(0.15));
  }
}

// ─────────────────────────────────────────────
// CATEGORY SECTION
// ─────────────────────────────────────────────

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.games,
    required this.matchId,
    required this.sectionIndex,
  });

  final GameCategory   category;
  final List<GameMeta> games;
  final String         matchId;
  final int            sectionIndex;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category header
          Row(children: [
            Text(category.label,
                style: AppTypography.titleSmall.copyWith(
                  color: AppColors.neutral700)),
            const SizedBox(width: 8),
            Text(category.labelAr,
                style: const TextStyle(
                  fontFamily: 'Scheherazade',
                  fontSize:   14,
                  color:      AppColors.neutral500,
                  height:     1.6,
                )),
            const Spacer(),
            Text(
              '${games.where((g) => g.unlocked).length}/${games.length}',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.neutral500),
            ),
          ]),
          const SizedBox(height: 10),

          // Game grid — 2 columns, fixed height cards
          GridView.builder(
            shrinkWrap: true,
            physics:    const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount:  3,
              mainAxisSpacing: 10,
              crossAxisSpacing:10,
              childAspectRatio: 0.85,
            ),
            itemCount:   games.length,
            itemBuilder: (context, i) => GameCard(
              game:  games[i],
              index: sectionIndex * 10 + i,
              onTap: () => context.push(
                  AppRoutes.gamePlayPath(matchId, games[i].type)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// MEMORY TIMELINE BOTTOM SHEET
// ─────────────────────────────────────────────

class _MemoryTimelineSheet extends StatelessWidget {
  const _MemoryTimelineSheet({required this.timelineAsync});
  final AsyncValue<MemoryTimeline> timelineAsync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height:      MediaQuery.of(context).size.height * 0.75,
      decoration:  BoxDecoration(
        color:        theme.colorScheme.surface,
        borderRadius: AppRadius.bottomSheet,
      ),
      child: Column(children: [
        // Handle
        Container(
          margin:      const EdgeInsets.only(top: 12),
          width: 40, height: 4,
          decoration:  BoxDecoration(
            color:        theme.colorScheme.outline.withOpacity(0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        // Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            const Text('📜', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Text('Match Memory',
                style: AppTypography.titleLarge.copyWith(
                  color: AppColors.roseDeep, fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(height: 16),
        // Timeline
        Expanded(
          child: timelineAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(
                color: AppColors.roseDeep, strokeWidth: 2)),
            error:   (e, _) => Center(child: Text('$e')),
            data: (timeline) => timeline.entries.isEmpty
                ? const _EmptyTimeline()
                : ListView.separated(
                    padding:       const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    itemCount:     timeline.entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 0),
                    itemBuilder:   (_, i) {
                      final entry = timeline.entries[i];
                      return _TimelineItem(
                        entry: entry,
                        isLast: i == timeline.entries.length - 1,
                      ).animate(delay: Duration(milliseconds: i * 40))
                       .fadeIn(duration: 300.ms)
                       .slideX(begin: -0.03, end: 0);
                    },
                  ),
          ),
        ),
      ]),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.entry, required this.isLast});
  final TimelineEntry entry;
  final bool          isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line + icon
          SizedBox(
            width: 40,
            child: Column(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color:  entry.isMilestone
                      ? AppColors.goldPrimary.withOpacity(0.12)
                      : AppColors.roseDeep.withOpacity(0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: entry.isMilestone
                        ? AppColors.goldPrimary.withOpacity(0.3)
                        : AppColors.roseDeep.withOpacity(0.2),
                  ),
                ),
                child: Center(
                  child: Text(entry.icon,
                      style: const TextStyle(fontSize: 16)),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                ),
            ]),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.title,
                      style: AppTypography.bodyMedium.copyWith(
                        color:      AppColors.neutral900,
                        fontWeight: FontWeight.w500,
                      )),
                  if (entry.date != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(entry.date!),
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.neutral500),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

class _EmptyTimeline extends StatelessWidget {
  const _EmptyTimeline();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🌱', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 16),
        Text('Your story is just beginning',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.neutral700),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('Complete games to build your Match Memory timeline.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.neutral500, height: 1.6)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// ERROR STATE
// ─────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String       message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.games_outlined,
            size: 48, color: AppColors.neutral300),
        const SizedBox(height: 20),
        Text(message, textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.neutral500)),
        const SizedBox(height: 24),
        MiskButton(
          label:     'Try again',
          onPressed: onRetry,
          variant:   MiskButtonVariant.outline,
          fullWidth: false,
          icon:      Icons.refresh_rounded,
        ),
      ]),
    );
  }
}
