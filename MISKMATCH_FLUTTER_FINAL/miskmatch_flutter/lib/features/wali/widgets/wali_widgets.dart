import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../data/wali_models.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/shared/widgets/common_widgets.dart';

// ═══════════════════════════════════════════════════════════════════
// FLAGGED MESSAGE CARD
// ═══════════════════════════════════════════════════════════════════

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
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      decoration: BoxDecoration(
        color:        theme.colorScheme.surface,
        borderRadius: AppRadius.cardRadius,
        boxShadow:    AppShadows.card,
        border: Border.all(color: AppColors.error.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.xl)),
            ),
            child: Row(children: [
              const Icon(Icons.flag_rounded, color: AppColors.error, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Flagged message${message.wardName != null ? ' in ${message.wardName}\'s chat' : ''}',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.error),
                ),
              ),
              Text(
                timeago.format(message.flaggedAt),
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.neutral500),
              ),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sender
                Row(children: [
                  const Icon(Icons.person_outline_rounded,
                      size: 14, color: AppColors.neutral500),
                  const SizedBox(width: 6),
                  Text('From: ${message.senderName}',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.neutral600)),
                ]),

                const SizedBox(height: 10),

                // Message content
                Container(
                  width:   double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color:        AppColors.errorLight,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: AppColors.error.withOpacity(0.2)),
                  ),
                  child: Text(
                    message.content,
                    style: AppTypography.bodyMedium.copyWith(
                      color:  AppColors.neutral900,
                      height: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Moderation reason
                Row(children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: AppColors.neutral500),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Flagged: ${message.moderationReason}',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.neutral500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ]),

                const SizedBox(height: 16),

                // Info note
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:        AppColors.neutral100,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(children: [
                    const Text('🤲', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This message was blocked before delivery. '
                        'Your ward was not harmed. If you have concerns, '
                        'you may close this match from the match screen.',
                        style: AppTypography.bodySmall.copyWith(
                          color:  AppColors.neutral600,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate(delay: Duration(milliseconds: index * 60))
        .fadeIn(duration: 350.ms)
        .slideX(begin: -0.03, end: 0);
  }
}

// ═══════════════════════════════════════════════════════════════════
// WARD SUMMARY CARD
// ═══════════════════════════════════════════════════════════════════

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
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        theme.colorScheme.surface,
          borderRadius: AppRadius.cardRadius,
          boxShadow:    AppShadows.card,
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
        ),
        child: Row(children: [
          // Avatar
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
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
                Row(children: [
                  Text(ward.displayName,
                      style: AppTypography.titleSmall),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color:        AppColors.roseDeep.withOpacity(0.08),
                      borderRadius: AppRadius.chipRadius,
                    ),
                    child: Text(ward.relationship.label,
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.roseDeep)),
                  ),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  if (ward.pendingDecisions > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: AppRadius.chipRadius,
                      ),
                      child: Text(
                        '${ward.pendingDecisions} pending',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (ward.activeMatches > 0)
                    Text(
                      '${ward.activeMatches} active match${ward.activeMatches == 1 ? '' : 'es'}',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.neutral500),
                    )
                  else
                    Text('No active matches',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.neutral500)),
                ]),
              ],
            ),
          ),

          const Icon(Icons.chevron_right_rounded,
              color: AppColors.neutral300, size: 20),
        ]),
      ),
    )
        .animate(delay: Duration(milliseconds: index * 60))
        .fadeIn(duration: 350.ms)
        .slideX(begin: 0.03, end: 0);
  }
}

extension on AppColors {
  static const neutral600 = Color(0xFF6B6B8B);
}
