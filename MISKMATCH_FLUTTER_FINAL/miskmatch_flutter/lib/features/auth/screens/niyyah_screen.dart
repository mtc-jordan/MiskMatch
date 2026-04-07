import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:miskmatch/core/router/app_router.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/shared/widgets/common_widgets.dart';

/// Niyyah (intention) screen — the user states their sincere intention
/// before proceeding. A beautiful, spiritually grounding onboarding step.
///
/// "إنما الأعمال بالنيات"
/// Actions are judged by intentions. — Bukhari & Muslim

class NiyyahScreen extends ConsumerStatefulWidget {
  const NiyyahScreen({super.key});

  @override
  ConsumerState<NiyyahScreen> createState() => _NiyyahScreenState();
}

class _NiyyahScreenState extends ConsumerState<NiyyahScreen> {
  final _niyyahCtrl = TextEditingController();
  bool  _agreed     = false;

  static const _suggestions = [
    'To find a righteous spouse and build a home filled with the remembrance of Allah.',
    'To complete half my deen with someone who shares my values and love for Islam.',
    'To find a partner who will be my companion in this life and the next, in sha Allah.',
    'To marry with good intention, following the Sunnah of our Prophet (SAW).',
  ];

  @override
  void dispose() {
    _niyyahCtrl.dispose();
    super.dispose();
  }

  void _continue() {
    if (!_agreed) return;
    // TODO: save niyyah to profile via API
    context.go(AppRoutes.waliSetup);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end:   Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary.withOpacity(0.05),
              theme.scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding),
            child: Column(
              children: [
                const SizedBox(height: 32),

                // ── Arabic hadith ─────────────────────────────────────────
                _NiyyahHeader()
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .slideY(begin: -0.05, end: 0),

                const SizedBox(height: 32),

                // ── Intention text field ──────────────────────────────────
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('State your intention (niyyah)',
                        style: AppTypography.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      'Write in your own words why you are seeking marriage.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.neutral500,
                      ),
                    ),
                    const SizedBox(height: 14),
                    MiskTextField(
                      label:      'Your niyyah',
                      hint:       'I seek marriage with the sincere intention of...',
                      controller: _niyyahCtrl,
                      maxLines:   4,
                      maxLength:  300,
                      onChanged:  (_) => setState(() {}),
                    ),
                  ],
                )
                    .animate(delay: 200.ms)
                    .fadeIn(duration: 400.ms),

                const SizedBox(height: 16),

                // ── Suggestion chips ──────────────────────────────────────
                _SuggestionChips(
                  suggestions: _suggestions,
                  onSelect: (s) {
                    _niyyahCtrl.text = s;
                    setState(() {});
                  },
                )
                    .animate(delay: 300.ms)
                    .fadeIn(duration: 400.ms),

                const SizedBox(height: 28),

                // ── Commitment checkbox ───────────────────────────────────
                _CommitmentBox(
                  agreed:    _agreed,
                  onChanged: (v) => setState(() => _agreed = v),
                )
                    .animate(delay: 400.ms)
                    .fadeIn(duration: 400.ms),

                const SizedBox(height: 28),

                // ── Continue button ───────────────────────────────────────
                MiskButton(
                  label:     'Bismillah — Begin',
                  onPressed: _agreed ? _continue : null,
                  icon:      Icons.arrow_forward_rounded,
                )
                    .animate(delay: 500.ms)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.1, end: 0),

                const SizedBox(height: 12),

                MiskButton(
                  label:     'Skip for now',
                  onPressed: () => context.go(AppRoutes.waliSetup),
                  variant:   MiskButtonVariant.ghost,
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SUB-WIDGETS
// ─────────────────────────────────────────────

class _NiyyahHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MiskCard(
      color: AppColors.roseDeep.withOpacity(0.04),
      child: Column(
        children: [
          const Text(
            'إنما الأعمال بالنيات',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Scheherazade',
              fontSize:   28,
              color:      AppColors.roseDeep,
              height:     1.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '"Actions are judged by intentions."',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color:      AppColors.neutral700,
              fontStyle:  FontStyle.italic,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '— Bukhari & Muslim',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.neutral500,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 1,
            color:  AppColors.roseLight,
          ),
          const SizedBox(height: 16),
          Text(
            'Before you begin, take a moment to set your sincere '
            'intention. MiskMatch is a space of dignity, guided '
            'by Islamic values.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color:  AppColors.neutral600,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

extension on AppColors {
  static const neutral600 = Color(0xFF6B6B8B);
}

class _SuggestionChips extends StatelessWidget {
  const _SuggestionChips({
    required this.suggestions,
    required this.onSelect,
  });

  final List<String>         suggestions;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Or choose a suggestion:',
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.neutral500,
            )),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: suggestions.map((s) {
            return GestureDetector(
              onTap: () => onSelect(s),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer
                      .withOpacity(0.5),
                  borderRadius: AppRadius.chipRadius,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary
                        .withOpacity(0.3),
                  ),
                ),
                child: Text(
                  s.length > 40 ? '${s.substring(0, 40)}…' : s,
                  style: AppTypography.bodySmall.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _CommitmentBox extends StatelessWidget {
  const _CommitmentBox({
    required this.agreed,
    required this.onChanged,
  });

  final bool                  agreed;
  final void Function(bool)   onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MiskCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value:           agreed,
            onChanged:       (v) => onChanged(v ?? false),
            activeColor:     theme.colorScheme.primary,
            shape:           RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: RichText(
                text: TextSpan(
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.neutral700,
                    height: 1.6,
                  ),
                  children: [
                    const TextSpan(
                      text: 'I commit to using MiskMatch with sincere '
                          'intention (niyyah) for marriage, treating all '
                          'members with Islamic dignity and respect, and '
                          'upholding the ',
                    ),
                    TextSpan(
                      text: 'Islamic communication guidelines',
                      style: TextStyle(
                        color:      theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const TextSpan(text: ' throughout my journey.'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
