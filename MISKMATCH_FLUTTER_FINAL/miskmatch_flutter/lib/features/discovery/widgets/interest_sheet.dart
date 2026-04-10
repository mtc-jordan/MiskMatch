import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miskmatch/features/profile/data/profile_models.dart';
import '../providers/discovery_provider.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/shared/widgets/common_widgets.dart';

/// Bottom sheet — express interest in a candidate.
/// Pre-populated with Islamic message suggestions.
/// Min 20 characters enforced (matches backend validation).

Future<bool?> showInterestSheet(
  BuildContext context,
  UserProfile  candidate,
  WidgetRef    ref,
) {
  return showModalBottomSheet<bool>(
    context:            context,
    isScrollControlled: true,
    backgroundColor:    Colors.transparent,
    builder: (_) => ProviderScope(
      parent: ProviderScope.containerOf(context),
      child: _InterestSheet(candidate: candidate),
    ),
  );
}

class _InterestSheet extends ConsumerStatefulWidget {
  const _InterestSheet({required this.candidate});
  final UserProfile candidate;

  @override
  ConsumerState<_InterestSheet> createState() => _InterestSheetState();
}

class _InterestSheetState extends ConsumerState<_InterestSheet> {
  final _msgCtrl  = TextEditingController();
  int   _selected = -1;

  static const _suggestions = [
    'Assalamu Alaikum. I read your profile carefully and was impressed '
        'by your commitment to your deen. I would be honoured to get to '
        'know you with good intentions, in sha Allah.',
    'Assalamu Alaikum. Your values and life goals resonated with me '
        'deeply. I hope we can get to know each other through this '
        'platform, with the blessing of our families.',
    'Assalamu Alaikum wa Rahmatullahi wa Barakatuh. I believe we may '
        'share compatible values and intentions. I would be grateful '
        'for the opportunity to learn more about you.',
    'Assalamu Alaikum. JazakAllah Khair for sharing your journey. '
        'I found your profile sincere and would like to express my '
        'interest with respectful intentions.',
  ];

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  void _selectSuggestion(int i) {
    HapticFeedback.selectionClick();
    setState(() {
      _selected = i;
      _msgCtrl.text = _suggestions[i];
    });
  }

  Future<void> _send() async {
    final message = _msgCtrl.text.trim();
    if (message.length < 20) return;
    HapticFeedback.mediumImpact();

    final success = await ref.read(discoveryProvider.notifier).expressInterest(
      receiverId: widget.candidate.userId,
      message:    message,
    );

    if (mounted) Navigator.of(context).pop(success);
  }

  @override
  Widget build(BuildContext context) {
    final message = _msgCtrl.text.trim();

    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x148B1A4A),
            blurRadius: 32,
            offset: Offset(0, -8),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Handle bar ─────────────────────────────────────────
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color:        context.handleColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Header — avatar + name ─────────────────────────────
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: const BoxDecoration(
                    gradient: AppColors.roseGradient,
                    shape:    BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      widget.candidate.firstName.isNotEmpty
                          ? widget.candidate.firstName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 20, color: AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Send interest to ${widget.candidate.displayFirstName}',
                    style: AppTypography.titleMedium.copyWith(
                      color:      context.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Wali notification gold chip ────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color:        AppColors.goldPrimary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: AppColors.goldPrimary.withOpacity(0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield_outlined,
                      size: 14, color: AppColors.goldPrimary),
                  const SizedBox(width: 6),
                  Text('Both walis will be notified',
                    style: AppTypography.labelSmall.copyWith(
                      color:      AppColors.goldPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Suggestion cards ───────────────────────────────────
            Text('Choose a message or write your own:',
              style: AppTypography.labelMedium.copyWith(
                color: context.mutedText)),

            const SizedBox(height: 12),

            ...List.generate(_suggestions.length, (i) {
              final isSelected = _selected == i;
              return GestureDetector(
                onTap: () => _selectSuggestion(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin:  const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.roseLight
                        : context.surfaceColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.roseDeep
                          : context.cardBorder,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isSelected)
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.roseDeep, size: 18)
                      else
                        Icon(Icons.radio_button_unchecked_rounded,
                            color: context.cardBorder, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _suggestions[i],
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall.copyWith(
                            color: isSelected
                                ? AppColors.roseDeep
                                : context.subtleText,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                    .animate(delay: Duration(milliseconds: i * 60))
                    .fadeIn(duration: 300.ms)
                    .slideX(begin: 0.03, end: 0),
              );
            }),

            const SizedBox(height: 12),

            // ── Custom text field ──────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color:        context.subtleBg.withOpacity(0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _selected == -1 && message.isNotEmpty
                      ? AppColors.roseDeep.withOpacity(0.4)
                      : context.cardBorder.withOpacity(0.5),
                ),
              ),
              child: TextField(
                controller:    _msgCtrl,
                maxLines:      4,
                maxLength:     500,
                textDirection: TextDirection.ltr,
                onChanged: (_) => setState(() => _selected = -1),
                style: AppTypography.bodyMedium.copyWith(
                  color: context.onSurface),
                decoration: InputDecoration(
                  hintText:    'Write a personalised message...',
                  hintStyle: AppTypography.bodyMedium.copyWith(
                    color: context.mutedText.withOpacity(0.6)),
                  border:          InputBorder.none,
                  contentPadding:  const EdgeInsets.all(16),
                  counterStyle: AppTypography.caption.copyWith(
                    color: context.mutedText),
                ),
              ),
            ),

            const SizedBox(height: 6),

            // ── Character count ────────────────────────────────────
            Text(
              message.length < 20
                  ? '${20 - message.length} more characters needed'
                  : '✓ Message ready',
              style: AppTypography.bodySmall.copyWith(
                color:    message.length >= 20
                    ? AppColors.success
                    : context.mutedText,
                fontSize: 11,
              ),
            ),

            const SizedBox(height: 20),

            // ── Islamic note ───────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:        AppColors.goldPrimary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Text('🤲', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your guardian must approve before a conversation '
                      'begins. Both walis will be notified of this interest.',
                      style: AppTypography.bodySmall.copyWith(
                        color:  AppColors.goldDark,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Send button — gold variant ─────────────────────────
            MiskButton(
              label:     'Send with bismillah',
              onPressed: message.length >= 20 ? _send : null,
              variant:   MiskButtonVariant.gold,
              icon:      Icons.send_rounded,
            ),

            const SizedBox(height: 10),

            MiskButton(
              label:     'Cancel',
              onPressed: () => Navigator.of(context).pop(false),
              variant:   MiskButtonVariant.ghost,
            ),
          ],
        ),
      ),
    );
  }
}
