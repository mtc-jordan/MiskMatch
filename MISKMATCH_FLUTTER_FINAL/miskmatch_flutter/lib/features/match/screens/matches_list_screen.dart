import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../data/match_models.dart';
import '../data/match_repository.dart';
import '../providers/match_provider.dart';
import 'package:miskmatch/features/auth/providers/auth_provider.dart';
import 'package:miskmatch/core/router/app_router.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/shared/widgets/common_widgets.dart';

/// All matches screen — grouped: Active → Awaiting families.

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

  Future<bool> _closeMatch(String matchId) async {
    final repo = ref.read(matchRepositoryProvider);
    final result = await repo.closeMatch(matchId, 'user_closed');
    return result.when(
      success: (_) {
        ref.read(matchListProvider.notifier).load(); // reload
        return true;
      },
      error: (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message)),
          );
        }
        return false;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(matchListProvider);
    final auth     = ref.watch(authProvider);
    final myUserId = auth is AuthAuthenticated ? auth.userId : '';

    return Scaffold(
      backgroundColor: context.scaffoldColor,
      body: CustomScrollView(
        slivers: [
          // ── App bar ────────────────────────────────────────────
          SliverAppBar(
            floating: true,
            snap:     true,
            backgroundColor: context.scaffoldColor,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            title: Row(
              children: [
                const Text('Matches',
                  style: TextStyle(
                    fontFamily:  'Georgia',
                    fontSize:    22,
                    fontWeight:  FontWeight.w700,
                    color:       AppColors.roseDeep,
                  ),
                ),
                if (state.totalUnread > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color:        AppColors.roseDeep,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text('${state.totalUnread}',
                      style: const TextStyle(
                        fontSize:   11,
                        color:      AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              IconButton(
                icon:  const Icon(Icons.refresh_rounded),
                color: context.mutedText,
                onPressed: () =>
                    ref.read(matchListProvider.notifier).load(),
              ),
              const SizedBox(width: 4),
            ],
          ),

          // ── Loading ────────────────────────────────────────────
          if (state.isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: CircularProgressIndicator(
                      color: AppColors.roseDeep, strokeWidth: 2),
                ),
              ),
            )

          // ── Error ──────────────────────────────────────────────
          else if (state.error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(children: [
                  const Icon(Icons.wifi_off_rounded,
                      size: 48, color: AppColors.neutral300),
                  const SizedBox(height: 16),
                  Text(state.error!.message,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(
                      color: context.mutedText),
                  ),
                  const SizedBox(height: 20),
                  MiskButton(
                    label:     'Retry',
                    onPressed: () =>
                        ref.read(matchListProvider.notifier).load(),
                    variant:   MiskButtonVariant.outline,
                    fullWidth: false,
                  ),
                ]),
              ),
            )

          // ── Both sections empty ────────────────────────────────
          else if (state.matches.isEmpty)
            const SliverToBoxAdapter(child: _GlobalEmptyState())

          // ── Content ────────────────────────────────────────────
          else ...[
            // ── ACTIVE MATCHES ─────────────────────────────────
            _SectionHeader(
              title: 'Active Matches',
              count: state.activeMatches.length,
            ),
            if (state.activeMatches.isEmpty)
              const SliverToBoxAdapter(
                child: _SectionEmptyState(
                  label: 'No active matches yet',
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _MatchTile(
                    match:    state.activeMatches[i],
                    myUserId: myUserId,
                    index:    i,
                    onTap:    () => ctx.push(
                        AppRoutes.matchPath(state.activeMatches[i].id)),
                    onClose:  () => _closeMatch(state.activeMatches[i].id),
                  ),
                  childCount: state.activeMatches.length,
                ),
              ),

            // ── AWAITING FAMILIES ──────────────────────────────
            _SectionHeader(
              title: 'Awaiting Families',
              count: state.pendingMatches.length,
            ),
            if (state.pendingMatches.isEmpty)
              const SliverToBoxAdapter(
                child: _SectionEmptyState(
                  label: 'No pending matches yet',
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _MatchTile(
                    match:    state.pendingMatches[i],
                    myUserId: myUserId,
                    index:    i,
                    onTap:    () => ctx.push(
                        AppRoutes.matchPath(state.pendingMatches[i].id)),
                    onClose:  () => _closeMatch(state.pendingMatches[i].id),
                  ),
                  childCount: state.pendingMatches.length,
                ),
              ),
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
        child: Row(
          children: [
            Text(title,
              style: AppTypography.labelMedium.copyWith(
                color:          context.mutedText,
                letterSpacing:  0.5,
                fontWeight:     FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color:        context.subtleBg,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text('$count',
                style: AppTypography.labelSmall.copyWith(
                  color: context.mutedText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// MATCH TILE — 80px, swipe actions
// ─────────────────────────────────────────────

class _MatchTile extends StatelessWidget {
  const _MatchTile({
    required this.match,
    required this.myUserId,
    required this.onTap,
    required this.onClose,
    this.index = 0,
  });

  final Match              match;
  final String             myUserId;
  final VoidCallback       onTap;
  final Future<bool> Function() onClose;
  final int                index;

  @override
  Widget build(BuildContext context) {
    final other     = match.otherProfile(myUserId);
    final name      = other?.displayFirstName ?? 'Match';
    final hasUnread = match.unreadCount > 0;

    return Dismissible(
      key: ValueKey(match.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding:   const EdgeInsets.only(right: 24),
        color:     AppColors.error.withOpacity(0.9),
        child: const Icon(Icons.delete_outline_rounded,
            color: AppColors.white, size: 24),
      ),
      confirmDismiss: (_) async {
        HapticFeedback.mediumImpact();
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Close this match?'),
            content: const Text(
              'This will respectfully end the match. '
              'Both you and the other person will be notified.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Close match'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          return await onClose();
        }
        return false;
      },
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: hasUnread ? context.scaffoldColor : context.surfaceColor,
            border: Border(
              bottom: BorderSide(
                color: context.cardBorder,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // ── Avatar with hero + unread badge ──────────────
              Hero(
                tag: 'match_avatar_${match.id}',
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 52, height: 52,
                      decoration: const BoxDecoration(
                        gradient: AppColors.roseGradient,
                        shape:    BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          name.isNotEmpty
                              ? name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize:   22,
                            color:      AppColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    // Red unread badge
                    if (hasUnread)
                      Positioned(
                        right: -2, top: -2,
                        child: Container(
                          width: 18, height: 18,
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: hasUnread
                                  ? context.scaffoldColor
                                  : context.surfaceColor,
                              width: 2,
                            ),
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
              ),

              const SizedBox(width: 14),

              // ── Centre column — name + message ───────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment:  MainAxisAlignment.center,
                  children: [
                    Text(name,
                      style: TextStyle(
                        fontSize:   15,
                        fontWeight: hasUnread
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: context.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    match.lastMessage != null
                        ? Text(
                            match.lastMessage!.isAudio
                                ? '🎙 Voice message'
                                : match.lastMessage!.content,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize:   13,
                              color:      hasUnread
                                  ? context.subtleText
                                  : context.mutedText,
                              fontWeight: hasUnread
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          )
                        : Text(
                            _statusHint(match),
                            style: TextStyle(
                              fontSize:   13,
                              color:      context.mutedText,
                              fontStyle:  FontStyle.italic,
                            ),
                          ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // ── Right column — time + compat ring ────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment:  MainAxisAlignment.center,
                children: [
                  if (match.lastMessage != null)
                    Text(
                      timeago.format(match.lastMessage!.createdAt,
                          allowFromNow: true),
                      style: TextStyle(
                        fontSize:   11,
                        color:      hasUnread
                            ? AppColors.roseDeep
                            : context.mutedText,
                        fontWeight: hasUnread
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  if (match.compatibilityScore != null) ...[
                    const SizedBox(height: 4),
                    CompatibilityRing(
                      score:     match.compatibilityScore!,
                      size:      32,
                      showLabel: false,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: index * 60))
        .fadeIn(duration: 350.ms)
        .slideY(begin: 0.05, end: 0, duration: 350.ms,
            curve: Curves.easeOutCubic);
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
// SECTION EMPTY STATE
// ─────────────────────────────────────────────

class _SectionEmptyState extends StatelessWidget {
  const _SectionEmptyState({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🌹', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Text(label,
            style: AppTypography.bodySmall.copyWith(
              color:     context.mutedText,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// GLOBAL EMPTY STATE
// ─────────────────────────────────────────────

class _GlobalEmptyState extends StatelessWidget {
  const _GlobalEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 60, 40, 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🌹', style: TextStyle(fontSize: 56))
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 0.9, end: 1.1, duration: 2000.ms,
                       curve: Curves.easeInOut),

          const SizedBox(height: 24),

          Text('No matches yet',
            style: TextStyle(
              fontFamily:  'Georgia',
              fontSize:    24,
              fontWeight:  FontWeight.w700,
              color:       context.subtleText,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 10),

          Text(
            'Express interest in candidates from the Discovery tab. '
            'When they reciprocate, a match is created, in sha Allah.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color:  context.mutedText,
              height: 1.6,
            ),
          ),
        ],
      ).animate().fadeIn(duration: 600.ms),
    );
  }
}
