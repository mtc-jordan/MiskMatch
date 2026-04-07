import 'package:flutter/material.dart';
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
  BuildContext     context,
  UserProfile      candidate,
  WidgetRef        ref,
) {
  return showModalBottomSheet<bool>(
    context:           context,
    isScrollControlled: true,
    backgroundColor:   Colors.transparent,
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
  final _msgCtrl   = TextEditingController();
  int   _selected  = -1; // index of suggestion, -1 = custom

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
    setState(() {
      _selected = i;
      _msgCtrl.text = _suggestions[i];
    });
  }

  Future<void> _send() async {
    final message = _msgCtrl.text.trim();
    if (message.length < 20) return;

    final success = await ref.read(discoveryProvider.notifier).expressInterest(
      receiverId: widget.candidate.userId,
      message:    message,
    );

    if (mounted) {
      Navigator.of(context).pop(success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme     = Theme.of(context);
    final feed      = ref.watch(discoveryProvider);
    final isSending = false; // simplified — check feed state if needed
    final message   = _msgCtrl.text.trim();

    return Container(
      decoration: BoxDecoration(
        color:        theme.colorScheme.surface,
        borderRadius: AppRadius.bottomSheet,
        boxShadow:    AppShadows.elevated,
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
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color:        theme.colorScheme.outline.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Header ───────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    gradient: AppColors.roseGradient,
                    shape:    BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      widget.candidate.firstName.isNotEmpty
                          ? widget.candidate.firstName[0]
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Send interest to ${widget.candidate.displayFirstName}',
                        style: AppTypography.titleMedium,
                      ),
                      Text(
                        'Your wali and theirs will both be notified.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.neutral500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Suggestion cards ──────────────────────────────────────
            Text('Choose a message or write your own:',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.neutral500,
                )),

            const SizedBox(height: 12),

            ...List.generate(_suggestions.length, (i) {
              final isSelected = _selected == i;
              return GestureDetector(
                onTap: () => _selectSuggestion(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color:        isSelected
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline.withOpacity(0.5),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (isSelected)
                        Icon(Icons.check_circle_rounded,
                            color: theme.colorScheme.primary, size: 18)
                      else
                        Icon(Icons.radio_button_unchecked_rounded,
                            color: theme.colorScheme.outline, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _suggestions[i],
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall.copyWith(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : AppColors.neutral700,
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

            // ── Custom message ────────────────────────────────────────
            TextFormField(
              controller: _msgCtrl,
              maxLines:   4,
              maxLength:  500,
              onChanged:  (_) => setState(() => _selected = -1),
              decoration: InputDecoration(
                labelText: 'Your message (min. 20 characters)',
                hintText:  'Write a personalised message...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: BorderSide(
                      color: theme.colorScheme.primary, width: 2),
                ),
              ),
              style: AppTypography.bodyMedium.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),

            const SizedBox(height: 8),

            // Character count / validation
            Text(
              message.length < 20
                  ? '${20 - message.length} more characters needed'
                  : '✓ Message ready',
              style: AppTypography.bodySmall.copyWith(
                color: message.length >= 20
                    ? AppColors.success
                    : AppColors.neutral500,
              ),
            ),

            const SizedBox(height: 20),

            // ── Islamic note ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:        AppColors.goldPrimary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  const Text('🤲', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Both walis will be notified. Your guardian '
                      'must approve before a conversation begins.',
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

            // ── Send button ───────────────────────────────────────────
            MiskButton(
              label:     'Send with bismillah',
              onPressed: message.length >= 20 ? _send : null,
              loading:   isSending,
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
