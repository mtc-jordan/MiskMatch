import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../data/game_models.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';

/// A single game card in the hub grid.
///
/// States:
///   Locked     — greyed out, countdown to unlock
///   Not started— inviting, "Start" CTA
///   My turn    — pulsing rose border, "Your turn!" badge
///   Waiting    — muted, "Waiting for match..."
///   Completed  — gold checkmark, full progress bar

class GameCard extends StatelessWidget {
  const GameCard({
    super.key,
    required this.game,
    required this.onTap,
    this.index = 0,
  });

  final GameMeta     game;
  final VoidCallback onTap;
  final int          index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: game.unlocked ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color:        _bgColor(theme),
          borderRadius: AppRadius.cardRadius,
          boxShadow:    game.unlocked ? AppShadows.card : [],
          border:       _border(theme),
        ),
        child: ClipRRect(
          borderRadius: AppRadius.cardRadius,
          child: Stack(
            children: [
              // Content
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon + my-turn badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(game.icon,
                            style: TextStyle(
                              fontSize: game.unlocked ? 28 : 22,
                            )),
                        const Spacer(),
                        if (game.status.isDone)
                          const _DoneBadge()
                        else if (game.myTurn)
                          const _MyTurnBadge()
                        else if (!game.unlocked)
                          _LockBadge(days: game.daysToUnlock),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Game name
                    Text(
                      game.name,
                      style: AppTypography.titleSmall.copyWith(
                        color:   game.unlocked
                            ? AppColors.neutral900
                            : AppColors.neutral500,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const Spacer(),

                    // Progress bar
                    if (game.unlocked && !game.status.isNew) ...[
                      _ProgressBar(
                          fraction: game.progressFraction,
                          isDone:   game.status.isDone),
                      const SizedBox(height: 6),
                      Text(
                        game.status.isDone
                            ? 'Complete ✓'
                            : game.myTurn
                                ? 'Your turn!'
                                : game.status.isPlayable
                                    ? game.progress
                                    : 'Not started',
                        style: AppTypography.labelSmall.copyWith(
                          color: game.status.isDone
                              ? AppColors.goldPrimary
                              : game.myTurn
                                  ? AppColors.roseDeep
                                  : AppColors.neutral500,
                          fontWeight: game.myTurn || game.status.isDone
                              ? FontWeight.w600
                              : FontWeight.w400,
                          fontSize: 10,
                        ),
                      ),
                    ] else if (!game.unlocked) ...[
                      Text(
                        'Day ${game.unlockDay}',
                        style: AppTypography.labelSmall.copyWith(
                          color:   AppColors.neutral500,
                          fontSize:10,
                        ),
                      ),
                    ] else ...[
                      Text(
                        'Tap to start',
                        style: AppTypography.labelSmall.copyWith(
                          color:   AppColors.roseDeep.withOpacity(0.7),
                          fontSize:10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Locked overlay
              if (!game.unlocked)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color:        AppColors.neutral100.withOpacity(0.6),
                      borderRadius: AppRadius.cardRadius,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: index * 30))
        .fadeIn(duration: 350.ms)
        .slideY(begin: 0.06, end: 0, duration: 350.ms,
            curve: Curves.easeOut);
  }

  Color _bgColor(ThemeData theme) {
    if (!game.unlocked)      return theme.colorScheme.surface.withOpacity(0.5);
    if (game.status.isDone)  return AppColors.goldPrimary.withOpacity(0.06);
    if (game.myTurn)         return AppColors.roseDeep.withOpacity(0.04);
    return theme.colorScheme.surface;
  }

  Border? _border(ThemeData theme) {
    if (game.myTurn) {
      return Border.all(color: AppColors.roseDeep.withOpacity(0.5), width: 2);
    }
    if (game.status.isDone) {
      return Border.all(color: AppColors.goldPrimary.withOpacity(0.3), width: 1.5);
    }
    return Border.all(
        color: theme.colorScheme.outlineVariant.withOpacity(0.4), width: 1);
  }
}

// ─────────────────────────────────────────────
// BADGE WIDGETS
// ─────────────────────────────────────────────

class _MyTurnBadge extends StatelessWidget {
  const _MyTurnBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        gradient:     AppColors.roseGradient,
        borderRadius: AppRadius.chipRadius,
      ),
      child: Text('Your turn',
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.white, fontSize: 9, fontWeight: FontWeight.w700)),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(begin: 1.0, end: 1.05, duration: 800.ms);
  }
}

class _DoneBadge extends StatelessWidget {
  const _DoneBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24, height: 24,
      decoration: BoxDecoration(
        color:  AppColors.goldPrimary.withOpacity(0.15),
        shape:  BoxShape.circle,
        border: Border.all(color: AppColors.goldPrimary.withOpacity(0.4)),
      ),
      child: const Icon(Icons.check_rounded,
          color: AppColors.goldPrimary, size: 14),
    );
  }
}

class _LockBadge extends StatelessWidget {
  const _LockBadge({required this.days});
  final int days;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.lock_rounded, size: 12, color: AppColors.neutral500),
        const SizedBox(width: 3),
        Text('${days}d',
            style: AppTypography.labelSmall.copyWith(
              color:   AppColors.neutral500,
              fontSize:10,
            )),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.fraction, required this.isDone});
  final double fraction;
  final bool   isDone;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        value:            fraction,
        backgroundColor:  AppColors.neutral100,
        valueColor: AlwaysStoppedAnimation(
          isDone ? AppColors.goldPrimary : AppColors.roseDeep,
        ),
        minHeight: 4,
      ),
    );
  }
}
