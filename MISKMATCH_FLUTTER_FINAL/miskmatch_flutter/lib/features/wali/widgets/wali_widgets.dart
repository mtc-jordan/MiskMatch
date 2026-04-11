import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../data/wali_models.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/shared/widgets/common_widgets.dart';
import 'package:miskmatch/l10n/generated/app_localizations.dart';

// ═══════════════════════════════════════════════════════════
// FLAGGED MESSAGE CARD
// red 6% bg, red 20% border
// 🚩 banner, sender row, red-tint message box,
// moderation reason, reassurance note
// ═══════════════════════════════════════════════════════════

class FlaggedMessageCard extends StatelessWidget {
  const FlaggedMessageCard({
    super.key,
    required this.message,
    required this.index,
  });

  final FlaggedMessage message;
  final int            index;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      decoration: BoxDecoration(
        color:        AppColors.error.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        boxShadow:    context.cardShadow,
        border: Border.all(
          color: AppColors.error.withOpacity(0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Red banner header ───────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Text('🚩', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message.wardName != null ? S.of(context)!.flaggedInChat(message.wardName!) : S.of(context)!.flagged,
                    style: AppTypography.labelMedium.copyWith(
                      color:      AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  timeago.format(message.flaggedAt),
                  style: AppTypography.labelSmall.copyWith(
                    color: context.mutedText),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── From: sender name ────────────────────
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded,
                      size: 14, color: context.mutedText),
                    const SizedBox(width: 6),
                    Text(S.of(context)!.fromSender(message.senderName),
                      style: AppTypography.labelMedium.copyWith(
                        color: context.subtleText),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ── Message content — red tint box ───────
                Container(
                  width:   double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color:        context.errorLightBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.error.withOpacity(0.2)),
                  ),
                  child: Text(
                    message.content,
                    style: AppTypography.bodyMedium.copyWith(
                      color:  context.onSurface,
                      height: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // ── Moderation reason ────────────────────
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                      size: 14, color: context.mutedText),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        S.of(context)!.flaggedReason(message.moderationReason),
                        style: AppTypography.bodySmall.copyWith(
                          color:     context.mutedText,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Reassurance note ─────────────────────
                Container(
                  width:   double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:        context.subtleBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🤲', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          S.of(context)!.messageBlockedNotice,
                          style: AppTypography.bodySmall.copyWith(
                            color:  context.mutedText,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate(delay: Duration(milliseconds: index * 60))
        .fadeIn(duration: 350.ms)
        .slideY(begin: 0.05, end: 0, duration: 350.ms,
            curve: Curves.easeOutCubic);
  }
}

// ═══════════════════════════════════════════════════════════
// WARD SUMMARY CARD
// Rose gradient left border 3px
// 52px avatar + name + relationship chip
// Pending badge (red) + active matches count
// ═══════════════════════════════════════════════════════════

class WardSummaryCard extends StatelessWidget {
  const WardSummaryCard({
    super.key,
    required this.ward,
    required this.onTap,
    this.index = 0,
  });

  final Ward         ward;
  final VoidCallback onTap;
  final int          index;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        context.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow:    context.cardShadow,
          border: const Border(
            left: BorderSide(
              color: AppColors.roseDeep,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            // 52px avatar
            Container(
              width: 52, height: 52,
              decoration: const BoxDecoration(
                gradient: AppColors.roseGradient,
                shape:    BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  ward.firstName.isNotEmpty
                      ? ward.firstName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize:   22,
                    color:      AppColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + relationship chip
                  Row(
                    children: [
                      Text(ward.displayName,
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.roseDeep.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(ward.relationship.label,
                          style: AppTypography.labelSmall.copyWith(
                            color:    AppColors.roseDeep,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Pending badge + active matches
                  Row(
                    children: [
                      if (ward.pendingDecisions > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color:        AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            '${ward.pendingDecisions} pending',
                            style: AppTypography.labelSmall.copyWith(
                              color:      AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        ward.activeMatches > 0
                            ? S.of(context)!.activeMatchesCount('${ward.activeMatches}')
                            : S.of(context)!.noActiveMatches,
                        style: AppTypography.bodySmall.copyWith(
                          color: context.mutedText),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? Icons.chevron_left_rounded
                  : Icons.chevron_right_rounded,
              color: AppColors.neutral300, size: 20),
          ],
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: index * 60))
        .fadeIn(duration: 350.ms)
        .slideY(begin: 0.05, end: 0, duration: 350.ms,
            curve: Curves.easeOutCubic);
  }
}
