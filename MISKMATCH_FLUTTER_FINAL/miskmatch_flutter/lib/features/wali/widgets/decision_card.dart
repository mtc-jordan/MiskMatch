import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/wali_models.dart';
import '../providers/wali_provider.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/shared/widgets/common_widgets.dart';
import 'package:miskmatch/l10n/generated/app_localizations.dart';

/// Decision card for pending match approvals in the Wali Portal.
///
/// Top banner: gold 8% bg, 🛡️ + "Decision required for [Name]"
/// Content: avatar + name/age/city + trust badges + CompatibilityRing
/// Islamic signals panel, message bubble, bio preview
/// Approve/Decline buttons. Stagger 80ms, slideY + fadeIn.

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
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      decoration: BoxDecoration(
        color:        context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow:    context.cardShadow,
        border: Border.all(
          color: AppColors.goldPrimary.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Gold top banner ─────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.goldPrimary.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Text('🛡️', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Decision required for ${decision.wardName}',
                    style: AppTypography.labelMedium.copyWith(
                      color:      AppColors.goldDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Candidate row: avatar + info + ring ───
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 64px avatar
                    Container(
                      width: 64, height: 64,
                      decoration: const BoxDecoration(
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

                    // Name + age + city + trust badges
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: decision.candidateName,
                                  style: TextStyle(
                                    fontFamily:  'Georgia',
                                    fontSize:    18,
                                    fontWeight:  FontWeight.w700,
                                    color:       context.onSurface,
                                  ),
                                ),
                                if (decision.candidateAge != null)
                                  TextSpan(
                                    text: ', ${decision.candidateAge}',
                                    style: TextStyle(
                                      fontFamily: 'Georgia',
                                      fontSize:   18,
                                      color:      context.mutedText,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (decision.candidateCity != null) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Text('📍',
                                  style: TextStyle(fontSize: 11)),
                                const SizedBox(width: 3),
                                Text(decision.candidateCity!,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: context.mutedText),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 6),
                          Wrap(spacing: 6, runSpacing: 4, children: [
                            if (decision.candidateMosqueVerified)
                              const TrustBadge(type: TrustBadgeType.mosque),
                            if (decision.candidateTrustScore >= 70)
                              const TrustBadge(type: TrustBadgeType.identity),
                          ]),
                        ],
                      ),
                    ),

                    // 60px CompatibilityRing
                    if (decision.compatibilityScore > 0)
                      CompatibilityRing(
                        score: decision.compatibilityScore,
                        size:  60,
                      ),
                  ],
                ),

                const SizedBox(height: 14),

                // ── Islamic signals panel ─────────────────
                _IslamicSignals(decision: decision),

                const SizedBox(height: 14),

                // ── Message bubble ────────────────────────
                Container(
                  width:   double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color:        context.subtleBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.neutral300.withOpacity(0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded,
                            size: 14, color: context.mutedText),
                          const SizedBox(width: 6),
                          Text(S.of(context)!.theirMessage,
                            style: AppTypography.labelSmall.copyWith(
                              color: context.mutedText),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        decision.senderMessage.isNotEmpty
                            ? decision.senderMessage
                            : S.of(context)!.noMessageProvided,
                        style: AppTypography.bodySmall.copyWith(
                          color:  context.subtleText,
                          height: 1.6,
                          fontStyle: decision.senderMessage.isEmpty
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Bio preview ──────────────────────────
                if (decision.candidateBio != null &&
                    decision.candidateBio!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    decision.candidateBio!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color:  context.mutedText,
                      height: 1.6,
                    ),
                  ),
                ],

                const SizedBox(height: 18),

                // ── Action buttons ───────────────────────
                Row(
                  children: [
                    // Decline — outline red
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showDecisionSheet(
                            context, ref, approved: false),
                        icon: const Icon(Icons.close_rounded,
                          color: AppColors.error, size: 18),
                        label: Text(S.of(context)!.decline),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Approve — green filled (flex 2)
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () => _showDecisionSheet(
                            context, ref, approved: true),
                        icon: const Icon(Icons.check_rounded,
                          color: AppColors.white, size: 18),
                        label: Text(S.of(context)!.approve),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
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

  void _showDecisionSheet(BuildContext context, WidgetRef ref,
      {required bool approved}) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => ProviderScope(
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
// ISLAMIC SIGNALS PANEL
// rose 4% bg, rose 10% border
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
      items.add(('Madhab',
          '📚 ${ml[decision.candidateMadhab] ?? decision.candidateMadhab!}'));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        AppColors.roseDeep.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.roseDeep.withOpacity(0.10)),
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
                  color:    context.mutedText,
                  fontSize: 10,
                ),
              ),
              Text(value,
                style: AppTypography.bodySmall.copyWith(
                  color:      context.subtleText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// DECISION CONFIRMATION SHEET
// Handle, emoji 44pt spring scale,
// Islamic reference card, notes, confirm/cancel
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
    final notifier = ref.read(waliDashboardProvider.notifier);

    final success = await notifier.decide(
      matchId:  widget.decision.matchId,
      approved: widget.approved,
      notes:    _notesCtrl.text.trim(),
    );

    if (mounted) {
      Navigator.of(context).pop();
      if (success) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.approved
                  ? S.of(context)!.matchApprovedMsg
                  : S.of(context)!.matchDeclinedMsg,
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
    final isApprove = widget.approved;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color:        context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color:        AppColors.neutral300.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Emoji 44pt, spring scale
            Text(
              isApprove ? '🤲' : '🙏',
              style: const TextStyle(fontSize: 44),
            ).animate().scale(
              begin:    const Offset(0.5, 0.5),
              end:      const Offset(1.0, 1.0),
              duration: 500.ms,
              curve:    Curves.elasticOut,
            ),

            const SizedBox(height: 16),

            // Title
            Text(
              isApprove
                  ? S.of(context)!.approveThisMatch
                  : S.of(context)!.declineThisMatch,
              style: TextStyle(
                fontFamily:  'Georgia',
                fontSize:    22,
                fontWeight:  FontWeight.w700,
                color:       context.onSurface,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            // Description
            Text(
              isApprove
                  ? '${widget.decision.wardName} and '
                    '${widget.decision.candidateName} will be notified '
                    'and can begin communicating in sha Allah.'
                  : 'This candidate will be respectfully declined. '
                    '${widget.decision.wardName} will be informed.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color:  context.mutedText,
                height: 1.6,
              ),
            ),

            const SizedBox(height: 24),

            // Islamic reference card
            Container(
              width:   double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isApprove
                    ? AppColors.success.withOpacity(0.07)
                    : context.subtleBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isApprove ? '🌿' : '🤲',
                    style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isApprove
                          ? '"And of His signs is that He created for you '
                            'from yourselves mates..." — Quran 30:21'
                          : 'Your decision is your amanah. May Allah guide '
                            'you to what is best.',
                      style: AppTypography.bodySmall.copyWith(
                        color: isApprove
                            ? AppColors.success
                            : context.mutedText,
                        fontStyle: FontStyle.italic,
                        height:    1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Optional notes textarea
            TextField(
              controller: _notesCtrl,
              maxLines:   3,
              decoration: InputDecoration(
                labelText: S.of(context)!.notesOptional,
                hintText: isApprove
                    ? S.of(context)!.approveGuidanceHint
                    : 'Reason for declining (private — not shared)...',
                filled:    true,
                fillColor: context.surfaceColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: isApprove
                        ? AppColors.success
                        : context.mutedText,
                    width: 2,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Confirm button — full width, green/red
            SizedBox(
              width:  double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: dashState.isDeciding ? null : _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isApprove
                      ? AppColors.success
                      : AppColors.error,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                ),
                child: dashState.isDeciding
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                          color: AppColors.white, strokeWidth: 2.5),
                      )
                    : Text(
                        isApprove
                            ? S.of(context)!.yesApprove
                            : S.of(context)!.yesDecline,
                        style: const TextStyle(
                          fontSize:   15,
                          fontWeight: FontWeight.w600,
                          color:      AppColors.white,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 12),

            // Cancel — ghost button
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(S.of(context)!.goBackNotDecided,
                style: AppTypography.bodySmall.copyWith(
                  color: context.mutedText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
