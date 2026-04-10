import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../data/game_models.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';

/// Game card with 5 visual states:
///   LOCKED      — neutral100 70%, lock icon, "Day N"
///   NOT STARTED — white, 28pt icon, "Tap to start", My Turn badge pulse
///   IN PROGRESS — white, 4px progress bar, fraction text
///   AWAITING    — white muted, "Waiting..." chip
///   COMPLETED   — gold 6% tint, gold checkmark, 100% gold fill, "Complete ✓"

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
    return GestureDetector(
      onTap: game.unlocked
          ? () {
              HapticFeedback.lightImpact();
              onTap();
            }
          : null,
      child: AnimatedContainer(
        duration: 250.ms,
        decoration: BoxDecoration(
          color:        _bgColor(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow:    game.unlocked ? context.cardShadow : [],
          border:       _borderFor(context),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Top row: icon + badge ──────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(game.icon,
                          style: TextStyle(
                            fontSize: game.unlocked ? 28 : 22,
                          ),
                        ),
                        const Spacer(),
                        if (game.status.isDone)
                          const _DoneBadge()
                        else if (game.myTurn && game.unlocked)
                          const _MyTurnBadge()
                        else if (!game.unlocked)
                          Icon(Icons.lock_rounded,
                            size: 16, color: context.mutedText),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // ── Game name ──────────────────────────────
                    Text(
                      game.name,
                      style: AppTypography.titleSmall.copyWith(
                        color: game.unlocked
                            ? context.onSurface
                            : context.mutedText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const Spacer(),

                    // ── Bottom section per state ──────────────
                    _buildBottom(context),
                  ],
                ),
              ),

              // Locked overlay
              if (!game.unlocked)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color:        context.subtleBg.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
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

  Widget _buildBottom(BuildContext context) {
    // ── LOCKED ──
    if (!game.unlocked) {
      return Text(
        'Day ${game.unlockDay}',
        style: AppTypography.labelSmall.copyWith(
          color:    context.mutedText,
          fontSize: 10,
        ),
      );
    }

    // ── COMPLETED ──
    if (game.status.isDone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProgressBar(fraction: 1.0, isDone: true),
          const SizedBox(height: 4),
          Text('Complete ✓',
            style: AppTypography.labelSmall.copyWith(
              color:      AppColors.goldPrimary,
              fontWeight: FontWeight.w600,
              fontSize:   10,
            ),
          ),
        ],
      );
    }

    // ── AWAITING (not my turn, in progress) ──
    if (game.status.isPlayable && !game.myTurn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProgressBar(fraction: game.progressFraction, isDone: false),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color:        context.subtleBg,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text('Waiting...',
              style: AppTypography.labelSmall.copyWith(
                color:    context.mutedText,
                fontSize: 9,
              ),
            ),
          ),
        ],
      );
    }

    // ── IN PROGRESS (my turn) ──
    if (game.status.isPlayable && game.myTurn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProgressBar(fraction: game.progressFraction, isDone: false),
          const SizedBox(height: 4),
          Text(game.progress,
            style: AppTypography.labelSmall.copyWith(
              color:      AppColors.roseDeep,
              fontWeight: FontWeight.w600,
              fontSize:   10,
            ),
          ),
        ],
      );
    }

    // ── NOT STARTED ──
    return Text(
      'Tap to start',
      style: AppTypography.labelSmall.copyWith(
        color:    AppColors.roseDeep.withOpacity(0.7),
        fontSize: 10,
      ),
    );
  }

  Color _bgColor(BuildContext context) {
    if (!game.unlocked)      return context.subtleBg.withOpacity(0.5);
    if (game.status.isDone)  return AppColors.goldPrimary.withOpacity(0.06);
    if (game.status.isPlayable && !game.myTurn)
                             return context.surfaceColor.withOpacity(0.85);
    return context.surfaceColor;
  }

  Border _borderFor(BuildContext context) {
    if (game.status.isDone) {
      return Border.all(
        color: AppColors.goldPrimary.withOpacity(0.3), width: 1.5);
    }
    if (game.myTurn && game.unlocked) {
      return Border.all(
        color: AppColors.roseDeep.withOpacity(0.5), width: 2);
    }
    return Border.all(
      color: context.cardBorder.withOpacity(0.4), width: 1);
  }
}

// ─────────────────────────────────────────────
// MY TURN BADGE — rose pill, pulse scale
// ─────────────────────────────────────────────

class _MyTurnBadge extends StatelessWidget {
  const _MyTurnBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        gradient:     AppColors.roseGradient,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text('Your turn',
        style: AppTypography.labelSmall.copyWith(
          color:      AppColors.white,
          fontSize:   8,
          fontWeight: FontWeight.w700,
        ),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(begin: 1.0, end: 1.05, duration: 800.ms);
  }
}

// ─────────────────────────────────────────────
// DONE BADGE — gold checkmark circle
// ─────────────────────────────────────────────

class _DoneBadge extends StatelessWidget {
  const _DoneBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22, height: 22,
      decoration: BoxDecoration(
        color:  AppColors.goldPrimary.withOpacity(0.15),
        shape:  BoxShape.circle,
        border: Border.all(
          color: AppColors.goldPrimary.withOpacity(0.4)),
      ),
      child: const Icon(Icons.check_rounded,
        color: AppColors.goldPrimary, size: 13),
    );
  }
}

// ─────────────────────────────────────────────
// PROGRESS BAR — 4px, rose or gold
// ─────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.fraction, required this.isDone});
  final double fraction;
  final bool   isDone;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: TweenAnimationBuilder<double>(
        tween:    Tween(begin: 0, end: fraction),
        duration: 600.ms,
        curve:    Curves.easeOutCubic,
        builder: (_, value, __) => LinearProgressIndicator(
          value:           value,
          backgroundColor: context.subtleBg,
          valueColor: AlwaysStoppedAnimation(
            isDone ? AppColors.goldPrimary : AppColors.roseDeep,
          ),
          minHeight: 4,
        ),
      ),
    );
  }
}
