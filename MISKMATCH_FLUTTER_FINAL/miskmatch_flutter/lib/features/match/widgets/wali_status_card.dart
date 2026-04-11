import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../data/match_models.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/shared/widgets/common_widgets.dart';

// ═══════════════════════════════════════════════════════════
// WALI STATUS CARD
// ═══════════════════════════════════════════════════════════

class WaliStatusCard extends StatelessWidget {
  const WaliStatusCard({
    super.key,
    required this.match,
    required this.myUserId,
  });

  final Match  match;
  final String myUserId;

  @override
  Widget build(BuildContext context) {
    if (!match.status.needsWali && !match.status.isActive) {
      return const SizedBox.shrink();
    }

    final myApproved    = match.myWaliApproved(myUserId);
    final theirApproved = match.theirWaliApproved(myUserId);
    final bothApproved  = match.bothWalisApproved;

    final tintColor = bothApproved ? AppColors.success : AppColors.goldPrimary;
    final borderColor = bothApproved ? AppColors.success : AppColors.goldPrimary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color:        tintColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border(
          left: BorderSide(color: borderColor, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color:      tintColor.withOpacity(0.06),
            blurRadius: 8,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(children: [
              Icon(
                bothApproved
                    ? Icons.shield_rounded
                    : Icons.shield_outlined,
                color: borderColor,
                size:  20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  bothApproved
                      ? 'Both families have blessed this match'
                      : 'Awaiting family approval',
                  style: AppTypography.titleSmall.copyWith(
                    color:      bothApproved
                        ? AppColors.success
                        : AppColors.goldDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ]),

            const SizedBox(height: 16),

            // My guardian row
            _WaliRow(
              label:    'Your guardian',
              name:     null, // could populate from match data
              approved: myApproved,
            ),

            const SizedBox(height: 10),

            // Their guardian row
            _WaliRow(
              label:    'Their guardian',
              name:     null,
              approved: theirApproved,
            ),

            if (!bothApproved) ...[
              const SizedBox(height: 14),
              Text(
                'Both guardians must approve before you can chat.',
                style: AppTypography.bodySmall.copyWith(
                  color:  AppColors.goldDark.withOpacity(0.7),
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WaliRow extends StatelessWidget {
  const _WaliRow({
    required this.label,
    required this.name,
    required this.approved,
  });
  final String  label;
  final String? name;
  final bool    approved;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(
        approved
            ? Icons.check_circle_rounded
            : Icons.radio_button_unchecked_rounded,
        size:  18,
        color: approved ? AppColors.success : context.mutedText,
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
              style: AppTypography.bodySmall.copyWith(
                color:      approved
                    ? AppColors.success
                    : context.subtleText,
                fontWeight: approved
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
            ),
            if (name != null)
              Text(name!,
                style: AppTypography.caption.copyWith(
                  color: context.mutedText),
              ),
          ],
        ),
      ),
      Text(
        approved ? 'Approved ✓' : 'Waiting...',
        style: AppTypography.labelSmall.copyWith(
          color:      approved ? AppColors.success : context.mutedText,
          fontWeight: approved ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════
// MATCH TIMELINE CARD — vertical timeline with icon circles
// ═══════════════════════════════════════════════════════════

class MatchTimelineCard extends StatelessWidget {
  const MatchTimelineCard({super.key, required this.timeline});
  final List<Map<String, dynamic>> timeline;

  @override
  Widget build(BuildContext context) {
    if (timeline.isEmpty) return const SizedBox.shrink();

    final events = timeline.reversed.take(5).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:        context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow:    context.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            const Text('📜', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text('Our Journey',
              style: TextStyle(
                fontFamily:  'Georgia',
                fontSize:    16,
                fontWeight:  FontWeight.w700,
                color:       context.onSurface,
              ),
            ),
          ]),

          const SizedBox(height: 16),

          // Vertical timeline
          ...List.generate(events.length, (i) {
            final event = events[i];
            final icon  = event['icon']  as String? ?? '🌙';
            final title = event['title'] as String? ?? '';
            final date  = event['date']  as String?;
            final isLast = i == events.length - 1;

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon circle + vertical line
                  SizedBox(
                    width: 32,
                    child: Column(
                      children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.roseDeep.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(icon,
                              style: const TextStyle(fontSize: 14)),
                          ),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: context.subtleBg,
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Event text + date
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          bottom: isLast ? 0 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                            style: AppTypography.bodySmall.copyWith(
                              color:      context.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (date != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              _formatDate(date),
                              style: AppTypography.caption.copyWith(
                                color: context.mutedText),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      const months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${dt.day} ${months[dt.month]} ${dt.year}';
    } catch (e) {
      debugPrint('WaliStatusCard._formatDate parse failed: $e');
      return '';
    }
  }
}
