import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/wali_models.dart';
import '../providers/wali_provider.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/shared/widgets/common_widgets.dart';

/// A pending match decision card for the Wali Portal.
///
/// Shows:
///   - Ward's name (whose match this is)
///   - Candidate summary: name, age, city, Islamic practice signals
///   - Compatibility score ring
///   - The message the candidate sent
///   - Approve / Decline buttons with du'a confirmation sheet

class DecisionCard extends ConsumerWidget {
  const DecisionCard({
    super.key,
    required this.decision,
    required this.index,
  });

  final WaliMatchDecision decision;
  final int               index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      decoration: BoxDecoration(
        color:        theme.colorScheme.surface,
        borderRadius: AppRadius.cardRadius,
        boxShadow:    AppShadows.card,
        border: Border.all(
          color: AppColors.goldPrimary.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Ward label ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.goldPrimary.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.xl)),
            ),
            child: Row(children: [
              const Icon(Icons.shield_rounded,
                  color: AppColors.goldPrimary, size: 16),
              const SizedBox(width: 8),
              Text(
                'Decision required for ${decision.wardName}',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.goldDark),
              ),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Candidate summary ─────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        gradient: AppColors.roseGradient,
                        shape:    BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          decision.candidateName.isNotEmpty
                              ? decision.candidateName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize:   28,
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
                          RichText(
                            text: TextSpan(children: [
                              TextSpan(
                                text: decision.candidateName,
                                style: AppTypography.titleLarge.copyWith(
                                  color:      AppColors.neutral900,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (decision.candidateAge != null)
                                TextSpan(
                                  text: ', ${decision.candidateAge}',
                                  style: AppTypography.titleLarge.copyWith(
                                    color: AppColors.neutral500,
                                  ),
                                ),
                            ]),
                          ),
                          if (decision.candidateCity != null) ...[
                            const SizedBox(height: 2),
                            Row(children: [
                              const Icon(Icons.location_on_outlined,
                                  size: 13, color: AppColors.neutral500),
                              const SizedBox(width: 3),
                              Text(decision.candidateCity!,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.neutral500)),
                            ]),
                          ],
                          const SizedBox(height: 8),
                          Wrap(spacing: 6, runSpacing: 4, children: [
                            if (decision.candidateMosqueVerified)
                              const TrustBadge(type: TrustBadgeType.mosque),
                            if (decision.candidateTrustScore >= 70)
                              const TrustBadge(type: TrustBadgeType.identity),
                          ]),
                        ],
                      ),
                    ),
                    if (decision.compatibilityScore > 0)
                      CompatibilityRing(
                        score: decision.compatibilityScore,
                        size:  60,
                      ),
                  ],
                ),

                const SizedBox(height: 14),

                // ── Islamic signals ────────────────────────────────
                _IslamicSignals(decision: decision),

                const SizedBox(height: 14),

                // ── Message from candidate ─────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color:        AppColors.neutral100,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: AppColors.neutral300.withOpacity(0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.chat_bubble_outline_rounded,
                            size: 14, color: AppColors.neutral500),
                        const SizedBox(width: 6),
                        Text('Their message to ${decision.wardName}:',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.neutral500)),
                      ]),
                      const SizedBox(height: 8),
                      Text(
                        decision.senderMessage.isNotEmpty
                            ? decision.senderMessage
                            : 'No message provided.',
                        style: AppTypography.bodySmall.copyWith(
                          color:  AppColors.neutral700,
                          height: 1.6,
                          fontStyle: decision.senderMessage.isEmpty
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Candidate bio ──────────────────────────────────
                if (decision.candidateBio != null &&
                    decision.candidateBio!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    decision.candidateBio!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color:  AppColors.neutral600,
                      height: 1.6,
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // ── Action buttons ─────────────────────────────────
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _showDecisionSheet(context, ref, approved: false),
                      icon:  const Icon(Icons.close_rounded,
                          color: AppColors.error),
                      label: const Text('Decline'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.buttonRadius),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _showDecisionSheet(context, ref, approved: true),
                      icon:  const Icon(Icons.check_rounded,
                          color: AppColors.white),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.buttonRadius),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    )
        .animate(delay: Duration(milliseconds: index * 80))
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.06, end: 0);
  }

  void _showDecisionSheet(BuildContext context, WidgetRef ref,
      {required bool approved}) {
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder:            (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child:  _DecisionSheet(
          decision: decision,
          approved: approved,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ISLAMIC SIGNALS ROW
// ─────────────────────────────────────────────

class _IslamicSignals extends StatelessWidget {
  const _IslamicSignals({required this.decision});
  final WaliMatchDecision decision;

  @override
  Widget build(BuildContext context) {
    final items = <(String, String)>[];

    final prayerLabels = {
      'all_five':    '🕌 All 5 prayers',
      'most':        '🕌 Most prayers',
      'sometimes':   '🕋 Prays sometimes',
      'friday_only': '🕋 Fridays only',
      'working_on':  '📿 Working on it',
    };
    if (decision.candidatePrayerFreq != null) {
      final label = prayerLabels[decision.candidatePrayerFreq];
      if (label != null) items.add(('Prayer', label));
    }

    if (decision.candidateMadhab != null &&
        decision.candidateMadhab!.isNotEmpty) {
      final ml = {
        'hanafi': 'Hanafi', 'maliki': 'Maliki',
        'shafii': "Shafi'i", 'hanbali': 'Hanbali',
      };
      items.add(('Madhab', '📚 ${ml[decision.candidateMadhab] ?? decision.candidateMadhab!}'));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        AppColors.roseDeep.withOpacity(0.04),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.roseDeep.withOpacity(0.1)),
      ),
      child: Wrap(
        spacing: 16, runSpacing: 8,
        children: items.map((item) {
          final (label, value) = item;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.neutral500, fontSize: 10)),
              Text(value,
                  style: AppTypography.bodySmall.copyWith(
                    color:      AppColors.neutral800,
                    fontWeight: FontWeight.w500,
                  )),
            ],
          );
        }).toList(),
      ),
    );
  }
}

extension on AppColors {
  static const neutral600 = Color(0xFF6B6B8B);
  static const neutral800 = Color(0xFF2D2D4E);
}

// ─────────────────────────────────────────────
// DECISION CONFIRMATION SHEET
// ─────────────────────────────────────────────

class _DecisionSheet extends ConsumerStatefulWidget {
  const _DecisionSheet({required this.decision, required this.approved});
  final WaliMatchDecision decision;
  final bool              approved;

  @override
  ConsumerState<_DecisionSheet> createState() => _DecisionSheetState();
}

class _DecisionSheetState extends ConsumerState<_DecisionSheet> {
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final state    = ref.read(waliDashboardProvider);
    final notifier = ref.read(waliDashboardProvider.notifier);

    final success = await notifier.decide(
      matchId:  widget.decision.matchId,
      approved: widget.approved,
      notes:    _notesCtrl.text.trim(),
    );

    if (mounted) {
      Navigator.of(context).pop();
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.approved
                  ? 'Alhamdulillah — Match approved. Barakallah feekum.'
                  : 'Match respectfully declined.',
            ),
            backgroundColor: widget.approved
                ? AppColors.success
                : AppColors.neutral700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashState = ref.watch(waliDashboardProvider);
    final theme     = Theme.of(context);
    final isApprove = widget.approved;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color:        theme.colorScheme.surface,
        borderRadius: AppRadius.bottomSheet,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin:  const EdgeInsets.only(top: 12, bottom: 20),
              width:   40, height: 4,
              decoration: BoxDecoration(
                color:        theme.colorScheme.outline.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Islamic header
            Text(
              isApprove ? '🤲' : '🙏',
              style: const TextStyle(fontSize: 48),
            ).animate().scale(
              begin:    const Offset(0.6, 0.6),
              duration: 400.ms,
              curve:    Curves.elasticOut,
            ),

            const SizedBox(height: 16),

            Text(
              isApprove
                  ? 'Approve this match?'
                  : 'Decline this match?',
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.neutral900),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            Text(
              isApprove
                  ? '${widget.decision.wardName} and ${widget.decision.candidateName} '
                    'will be notified and can begin communicating in sha Allah.'
                  : 'This candidate will be respectfully declined. '
                    '${widget.decision.wardName} will be informed.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color:  AppColors.neutral500,
                height: 1.6,
              ),
            ),

            const SizedBox(height: 24),

            // Du'a / reminder
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isApprove
                    ? AppColors.success.withOpacity(0.07)
                    : AppColors.neutral100,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(children: [
                Text(isApprove ? '🌿' : '🤲',
                    style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isApprove
                        ? '"And of His signs is that He created for you '
                          'from yourselves mates..." — 30:21'
                        : 'Your decision is your amanah. May Allah guide '
                          'you to what is best.',
                    style: AppTypography.bodySmall.copyWith(
                      color:     isApprove ? AppColors.success : AppColors.neutral600,
                      fontStyle: FontStyle.italic,
                      height:    1.5,
                    ),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 20),

            // Optional notes
            TextField(
              controller: _notesCtrl,
              maxLines:   3,
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                hintText:  isApprove
                    ? 'Any conditions or guidance for this match...'
                    : 'Reason for declining (private — not shared)...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: BorderSide(
                    color: isApprove
                        ? AppColors.success
                        : theme.colorScheme.outline,
                    width: 2,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Confirm button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: dashState.isDeciding ? null : _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isApprove
                      ? AppColors.success
                      : AppColors.error,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.buttonRadius),
                ),
                child: dashState.isDeciding
                    ? const SizedBox(
                        width:  22, height: 22,
                        child:  CircularProgressIndicator(
                          color: AppColors.white, strokeWidth: 2.5),
                      )
                    : Text(
                        isApprove
                            ? 'Yes — approve this match'
                            : 'Yes — decline this match',
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.white, fontSize: 15),
                      ),
              ),
            ),

            const SizedBox(height: 12),

            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go back — not yet decided'),
            ),
          ],
        ),
      ),
    );
  }
}

extension on AppColors {
  static const neutral600 = Color(0xFF6B6B8B);
}
