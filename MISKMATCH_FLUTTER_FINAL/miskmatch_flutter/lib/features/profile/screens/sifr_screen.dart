import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/features/profile/data/profile_repository.dart';
import 'package:miskmatch/features/profile/providers/profile_provider.dart';
import 'package:miskmatch/l10n/generated/app_localizations.dart';
import 'package:miskmatch/shared/extensions/app_extensions.dart';
import 'package:miskmatch/shared/models/api_response.dart';
import 'package:miskmatch/shared/widgets/common_widgets.dart';

/// Sifr (صِفر) Islamic personality assessment — 15 Likert questions mapped
/// to 5 dimensions: generosity, patience, honesty, family, community.
/// Scores feed into the AI compatibility engine.

class SifrScreen extends ConsumerStatefulWidget {
  const SifrScreen({super.key});

  @override
  ConsumerState<SifrScreen> createState() => _SifrScreenState();
}

class _SifrScreenState extends ConsumerState<SifrScreen> {
  static const int _total = 15;

  bool _started = false;
  int  _index   = 0;
  bool _saving  = false;
  final Map<String, int> _answers = {};

  List<String> _questions(BuildContext context) {
    final l = S.of(context)!;
    return [
      l.sifrQ1,  l.sifrQ2,  l.sifrQ3,  l.sifrQ4,  l.sifrQ5,
      l.sifrQ6,  l.sifrQ7,  l.sifrQ8,  l.sifrQ9,  l.sifrQ10,
      l.sifrQ11, l.sifrQ12, l.sifrQ13, l.sifrQ14, l.sifrQ15,
    ];
  }

  String _key(int i) => 'q${i + 1}';

  void _setAnswer(int value) {
    HapticFeedback.selectionClick();
    setState(() => _answers[_key(_index)] = value);
  }

  void _next() {
    if (_index < _total - 1) {
      setState(() => _index++);
    }
  }

  void _back() {
    if (_index > 0) {
      setState(() => _index--);
    }
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final repo   = ref.read(profileRepositoryProvider);
    final result = await repo.submitSifr(Map<String, int>.from(_answers));
    if (!mounted) return;
    setState(() => _saving = false);

    switch (result) {
      case ApiSuccess():
        // Refresh cached profile so new sifr_scores are visible
        await ref.read(profileProvider.notifier).load();
        if (!mounted) return;
        context.showSuccessSnack(S.of(context)!.sifrSaved);
        context.pop();
      case ApiError(error: final e):
        context.showErrorSnack(e.message.isNotEmpty
            ? e.message
            : S.of(context)!.sifrSaveFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldColor,
      appBar: AppBar(
        backgroundColor: context.scaffoldColor,
        elevation:       0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon:      const Icon(Icons.arrow_back_rounded),
          color:     AppColors.roseDeep,
          onPressed: () => context.pop(),
        ),
        title: Text(
          S.of(context)!.sifrAssessmentTitle,
          style: const TextStyle(
            fontFamily: 'Georgia',
            fontSize:   20,
            fontWeight: FontWeight.w700,
            color:      AppColors.roseDeep,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _started ? _buildQuestion(context) : _buildIntro(context),
      ),
    );
  }

  // ── Intro card ─────────────────────────────────────────────────────────
  Widget _buildIntro(BuildContext context) {
    final l = S.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Container(
            width:  84,
            height: 84,
            decoration: const BoxDecoration(
              gradient: AppColors.roseGradient,
              shape:    BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: AppColors.white, size: 38),
          ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 24),
          Text(
            l.sifrIntroHeadline,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize:   24,
              height:     1.3,
              fontWeight: FontWeight.w700,
              color:      AppColors.roseDeep,
            ),
          ).animate(delay: 100.ms).fadeIn(duration: 400.ms),
          const SizedBox(height: 16),
          Text(
            l.sifrIntroBody,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: context.mutedText,
              height: 1.6,
            ),
          ).animate(delay: 200.ms).fadeIn(duration: 400.ms),
          const Spacer(),
          MiskButton(
            label:     l.sifrBegin,
            icon:      Icons.play_arrow_rounded,
            onPressed: () => setState(() => _started = true),
          ).animate(delay: 300.ms).fadeIn(duration: 400.ms),
        ],
      ),
    );
  }

  // ── Question page ──────────────────────────────────────────────────────
  Widget _buildQuestion(BuildContext context) {
    final l        = S.of(context)!;
    final question = _questions(context)[_index];
    final selected = _answers[_key(_index)];
    final isLast   = _index == _total - 1;
    final progress = (_index + 1) / _total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress bar + counter
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value:            progress,
                    minHeight:        6,
                    backgroundColor:  AppColors.roseDeep.withOpacity(0.12),
                    valueColor: const AlwaysStoppedAnimation(AppColors.roseDeep),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                l.sifrQuestionProgress(_index + 1, _total),
                style: AppTypography.labelSmall.copyWith(
                  color: context.mutedText),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Question text
          Text(
            question,
            key: ValueKey(_index),
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize:   22,
              height:     1.4,
              fontWeight: FontWeight.w600,
              color:      AppColors.roseDeep,
            ),
          ).animate(key: ValueKey('q$_index'))
              .fadeIn(duration: 300.ms)
              .slideY(begin: 0.05, end: 0, duration: 300.ms),

          const SizedBox(height: 32),

          // Likert scale (1..5)
          Expanded(
            child: ListView.separated(
              itemCount: 5,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final value  = 5 - i;       // 5 = strongly agree on top
                final labels = <String>[
                  l.sifrScaleStronglyAgree,
                  l.sifrScaleAgree,
                  l.sifrScaleNeutral,
                  l.sifrScaleDisagree,
                  l.sifrScaleStronglyDisagree,
                ];
                return _ScaleTile(
                  label:    labels[i],
                  value:    value,
                  selected: selected == value,
                  onTap:    () => _setAnswer(value),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Navigation row
          Row(
            children: [
              if (_index > 0)
                Expanded(
                  child: MiskButton(
                    label:     l.sifrBack,
                    variant:   MiskButtonVariant.outline,
                    onPressed: _saving ? null : _back,
                  ),
                ),
              if (_index > 0) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: MiskButton(
                  label: isLast ? l.sifrSubmit : l.sifrNext,
                  icon:  isLast
                      ? Icons.check_rounded
                      : Icons.arrow_forward_rounded,
                  loading: _saving,
                  onPressed: selected == null || _saving
                      ? null
                      : (isLast ? _submit : _next),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// SCALE TILE — one row in the likert scale
// ─────────────────────────────────────────────────────────────────────────

class _ScaleTile extends StatelessWidget {
  const _ScaleTile({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String       label;
  final int          value;
  final bool         selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border = selected
        ? AppColors.roseDeep
        : AppColors.roseDeep.withOpacity(0.20);
    final bg = selected
        ? AppColors.roseDeep.withOpacity(0.08)
        : context.surfaceColor;

    return Semantics(
      button:   true,
      selected: selected,
      label:    label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding:  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color:        bg,
            borderRadius: BorderRadius.circular(14),
            border:       Border.all(color: border, width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              // Numeric bubble
              Container(
                width:  34,
                height: 34,
                decoration: BoxDecoration(
                  shape:  BoxShape.circle,
                  color:  selected
                      ? AppColors.roseDeep
                      : AppColors.roseDeep.withOpacity(0.10),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$value',
                  style: TextStyle(
                    fontSize:   15,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? AppColors.white
                        : AppColors.roseDeep,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.bodyMedium.copyWith(
                    color: selected
                        ? AppColors.roseDeep
                        : context.onSurface,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.roseDeep, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
