import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../data/match_models.dart';
import '../providers/match_provider.dart';
import 'package:miskmatch/features/auth/providers/auth_provider.dart';
import 'package:miskmatch/core/router/app_router.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/shared/widgets/common_widgets.dart';

/// All matches screen — replaces the shell "Matches" tab.
/// Grouped: Active → Awaiting families → Closed.

class MatchesListScreen extends ConsumerStatefulWidget {
  const MatchesListScreen({super.key});

  @override
  ConsumerState<MatchesListScreen> createState() => _MatchesListScreenState();
}

class _MatchesListScreenState extends ConsumerState<MatchesListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(matchListProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(matchListProvider);
    final auth     = ref.read(authProvider);
    final myUserId = auth is AuthAuthenticated ? auth.userId : '';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap:     true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            title: Row(children: [
              Text('Matches',
                  style: AppTypography.titleLarge.copyWith(
                    color: AppColors.roseDeep, fontWeight: FontWeight.w700)),
              if (state.totalUnread > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.roseDeep,
                    borderRadius: AppRadius.chipRadius,
                  ),
                  child: Text('${state.totalUnread}',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.white, fontWeight: FontWeight.w700)),
                ),
              ],
            ]),
            actions: [
              IconButton(
                icon:      const Icon(Icons.refresh_rounded),
                color:     AppColors.neutral500,
                onPressed: () => ref.read(matchListProvider.notifier).load(),
              ),
            ],
          ),

          if (state.isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator(
                    color: AppColors.roseDeep, strokeWidth: 2)),
              ),
            )
          else if (state.error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(children: [
                  Text(state.error!.message,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.neutral500)),
                  const SizedBox(height: 20),
                  MiskButton(
                    label: 'Retry',
                    onPressed: () => ref.read(matchListProvider.notifier).load(),
                    fullWidth: false,
                  ),
                ]),
              ),
            )
          else if (state.matches.isEmpty)
            const SliverToBoxAdapter(child: _EmptyMatchesState())
          else ...[
            // Active matches
            if (state.activeMatches.isNotEmpty) ...[
              _SectionHeader(title: 'Active', count: state.activeMatches.length),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _MatchTile(
                    match:     state.activeMatches[i],
                    myUserId:  myUserId,
                    index:     i,
                    onTap:     () => ctx.push(AppRoutes.matchPath(state.activeMatches[i].id)),
                  ),
                  childCount: state.activeMatches.length,
                ),
              ),
            ],

            // Awaiting wali
            if (state.pendingMatches.isNotEmpty) ...[
              _SectionHeader(title: 'Awaiting families', count: state.pendingMatches.length),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _MatchTile(
                    match:    state.pendingMatches[i],
                    myUserId: myUserId,
                    index:    i,
                    onTap:    () => ctx.push(AppRoutes.matchPath(state.pendingMatches[i].id)),
                  ),
                  childCount: state.pendingMatches.length,
                ),
              ),
            ],
          ],

          const SliverToBoxAdapter(
              child: SizedBox(height: AppSpacing.bottomNavHeight + 16)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SECTION HEADER
// ─────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});
  final String title;
  final int    count;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Row(children: [
          Text(title,
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.neutral500,
                letterSpacing: 0.5,
              )),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color:        AppColors.neutral100,
              borderRadius: AppRadius.chipRadius,
            ),
            child: Text('$count',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.neutral500)),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// MATCH TILE
// ─────────────────────────────────────────────

class _MatchTile extends StatelessWidget {
  const _MatchTile({
    required this.match,
    required this.myUserId,
    required this.onTap,
    this.index = 0,
  });

  final Match        match;
  final String       myUserId;
  final VoidCallback onTap;
  final int          index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final other = match.otherProfile(myUserId);
    final name  = other?.displayFirstName ?? 'Match';
    final hasUnread = match.unreadCount > 0;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outline.withOpacity(0.2),
              width: 1,
            ),
          ),
          color: hasUnread
              ? AppColors.roseDeep.withOpacity(0.03)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    gradient: AppColors.roseGradient,
                    shape:    BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize:   22,
                        color:      AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                // Unread badge
                if (hasUnread)
                  Positioned(
                    right: 0, top: 0,
                    child: Container(
                      width: 18, height: 18,
                      decoration: const BoxDecoration(
                        color: AppColors.roseDeep,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${match.unreadCount}',
                          style: const TextStyle(
                            fontSize:   10,
                            color:      AppColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: AppTypography.titleSmall.copyWith(
                            fontWeight: hasUnread
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      // Time
                      if (match.lastMessage != null)
                        Text(
                          timeago.format(match.lastMessage!.createdAt,
                              allowFromNow: true),
                          style: AppTypography.labelSmall.copyWith(
                            color: hasUnread
                                ? AppColors.roseDeep
                                : AppColors.neutral500,
                            fontWeight: hasUnread
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 3),

                  // Last message or status
                  Row(
                    children: [
                      Expanded(
                        child: match.lastMessage != null
                            ? Text(
                                match.lastMessage!.isAudio
                                    ? '🎙 Voice message'
                                    : match.lastMessage!.content,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodySmall.copyWith(
                                  color: hasUnread
                                      ? AppColors.neutral700
                                      : AppColors.neutral500,
                                  fontWeight: hasUnread
                                      ? FontWeight.w500
                                      : FontWeight.w400,
                                ),
                              )
                            : Text(
                                _statusHint(match),
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.neutral500,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                      ),
                      // Compat ring (small)
                      if (match.compatibilityScore != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: CompatibilityRing(
                            score:     match.compatibilityScore!,
                            size:      32,
                            showLabel: false,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.neutral300, size: 20),
          ],
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: index * 40))
        .fadeIn(duration: 300.ms)
        .slideX(begin: 0.03, end: 0);
  }

  String _statusHint(Match match) {
    return switch (match.status) {
      MatchStatus.mutual   => '🤲 Awaiting family approval',
      MatchStatus.approved => '🤲 One family approved',
      MatchStatus.active   => '💬 Start chatting',
      MatchStatus.closed   => '✓ Closed respectfully',
      _                    => match.status.label,
    };
  }
}

// ─────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────

class _EmptyMatchesState extends StatelessWidget {
  const _EmptyMatchesState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 60, 40, 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🌹', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 24),
          Text('No matches yet',
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.neutral700),
              textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(
            'Express interest in candidates from the Discovery tab. '
            'When they reciprocate, a match is created, in sha Allah.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
                color: AppColors.neutral500, height: 1.6),
          ),
        ],
      ).animate().fadeIn(duration: 600.ms),
    );
  }
}
