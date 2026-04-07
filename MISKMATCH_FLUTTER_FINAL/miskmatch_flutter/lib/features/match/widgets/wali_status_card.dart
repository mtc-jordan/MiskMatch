import 'package:flutter/material.dart';
import '../data/match_models.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/shared/widgets/common_widgets.dart';

// ═══════════════════════════════════════════════════════════════════
// WALI STATUS CARD
// ═══════════════════════════════════════════════════════════════════

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

    return MiskCard(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      color:  bothApproved
          ? AppColors.success.withOpacity(0.05)
          : AppColors.goldPrimary.withOpacity(0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(
              bothApproved
                  ? Icons.shield_rounded
                  : Icons.shield_outlined,
              color:  bothApproved ? AppColors.success : AppColors.goldPrimary,
              size:   18,
            ),
            const SizedBox(width: 8),
            Text(
              bothApproved
                  ? 'Both families have given their blessing 🤲'
                  : 'Awaiting family blessings',
              style: AppTypography.titleSmall.copyWith(
                color: bothApproved ? AppColors.success : AppColors.goldDark,
              ),
            ),
          ]),

          const SizedBox(height: 14),

          // My wali
          _WaliRow(
            label:    'Your guardian',
            approved: myApproved,
          ),
          const SizedBox(height: 8),
          // Their wali
          _WaliRow(
            label:    'Their guardian',
            approved: theirApproved,
          ),

          if (!bothApproved) ...[
            const SizedBox(height: 14),
            Text(
              'Both guardians must approve before you can chat and play games.',
              style: AppTypography.bodySmall.copyWith(
                color:  AppColors.goldDark,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WaliRow extends StatelessWidget {
  const _WaliRow({required this.label, required this.approved});
  final String label;
  final bool   approved;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(
        approved ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
        size:  18,
        color: approved ? AppColors.success : AppColors.neutral500,
      ),
      const SizedBox(width: 8),
      Text(
        label,
        style: AppTypography.bodySmall.copyWith(
          color:      approved ? AppColors.success : AppColors.neutral700,
          fontWeight: approved ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      const Spacer(),
      Text(
        approved ? 'Approved ✓' : 'Pending...',
        style: AppTypography.labelSmall.copyWith(
          color: approved ? AppColors.success : AppColors.neutral500,
        ),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════
// MATCH TIMELINE CARD
// ═══════════════════════════════════════════════════════════════════

class MatchTimelineCard extends StatelessWidget {
  const MatchTimelineCard({super.key, required this.timeline});
  final List<Map<String, dynamic>> timeline;

  @override
  Widget build(BuildContext context) {
    if (timeline.isEmpty) return const SizedBox.shrink();

    return MiskCard(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('📜', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text('Our journey',
                style: AppTypography.titleSmall.copyWith(
                  color: AppColors.neutral900)),
          ]),
          const SizedBox(height: 14),

          // Timeline items — show latest 5
          ...timeline.reversed.take(5).map((event) {
            final icon  = event['icon']  as String? ?? '🌙';
            final title = event['title'] as String? ?? '';
            final date  = event['date']  as String?;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(icon,
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: AppTypography.bodySmall.copyWith(
                              color:      AppColors.neutral700,
                              fontWeight: FontWeight.w500,
                            )),
                        if (date != null)
                          Text(
                            _formatDate(date),
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.neutral500,
                            ),
                          ),
                      ],
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
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}
