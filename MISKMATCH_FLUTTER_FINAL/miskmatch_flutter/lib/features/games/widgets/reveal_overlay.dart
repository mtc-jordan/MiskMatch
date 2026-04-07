import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../data/game_models.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/shared/widgets/common_widgets.dart';

/// Full-screen reveal overlay — shown when both players have answered
/// in a real-time game (Would You Rather, Islamic Trivia, Geography Race).
///
/// Animation sequence:
///   1. Dark scrim fades in
///   2. "Both answered!" burst (scale + fade)
///   3. Two answer cards flip in — Mine (rose) | Theirs (neutral)
///   4. For trivia: correct answer highlight + scores
///   5. Dismiss button

class RevealOverlay extends StatelessWidget {
  const RevealOverlay({
    super.key,
    required this.result,
    required this.gameType,
    required this.onDismiss,
  });

  final TurnResult   result;
  final String       gameType;
  final VoidCallback onDismiss;

  bool get _isTrivia =>
      gameType == 'islamic_trivia' || gameType == 'geography_race';

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        color: Colors.black.withOpacity(0.80),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Header ─────────────────────────────────────────────
                _RevealHeader(gameType: gameType)
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .scale(begin: const Offset(0.6, 0.6),
                        duration: 500.ms, curve: Curves.elasticOut),

                const SizedBox(height: 32),

                // ── Answer cards ───────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _AnswerCard(
                        label:     'Your answer',
                        answer:    result.yourAnswer ?? '—',
                        isMe:      true,
                        isCorrect: result.youGotIt,
                        showCorrect: _isTrivia,
                      ).animate(delay: 300.ms)
                       .fadeIn(duration: 400.ms)
                       .slideX(begin: -0.15, end: 0, curve: Curves.easeOutCubic),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AnswerCard(
                        label:     'Their answer',
                        answer:    result.partnerAnswer ?? '—',
                        isMe:      false,
                        isCorrect: result.theyGotIt,
                        showCorrect: _isTrivia,
                      ).animate(delay: 450.ms)
                       .fadeIn(duration: 400.ms)
                       .slideX(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
                    ),
                  ],
                ),

                // ── Correct answer (trivia) ────────────────────────────
                if (_isTrivia && result.correctAnswer != null) ...[
                  const SizedBox(height: 20),
                  _CorrectAnswerBanner(answer: result.correctAnswer!)
                      .animate(delay: 650.ms)
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.1, end: 0),
                ],

                // ── Scores ────────────────────────────────────────────
                if (result.scores != null && result.scores!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _ScoreBanner(scores: result.scores!)
                      .animate(delay: 800.ms)
                      .fadeIn(duration: 300.ms),
                ],

                // ── Outcome message (WYR — same/different) ─────────────
                if (!_isTrivia) ...[
                  const SizedBox(height: 20),
                  _OutcomeMessage(
                    sameAnswer: result.yourAnswer == result.partnerAnswer,
                  ).animate(delay: 600.ms).fadeIn(duration: 400.ms),
                ],

                const SizedBox(height: 32),

                // ── Dismiss ───────────────────────────────────────────
                MiskButton(
                  label:     result.gameComplete
                      ? 'Masha\'Allah — Game complete! 🌙'
                      : 'Next question →',
                  onPressed: onDismiss,
                  variant:   result.gameComplete
                      ? MiskButtonVariant.gold
                      : MiskButtonVariant.primary,
                  icon: result.gameComplete
                      ? Icons.celebration_rounded
                      : Icons.arrow_forward_rounded,
                ).animate(delay: 1000.ms).fadeIn(duration: 400.ms),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 250.ms);
  }
}

// ─────────────────────────────────────────────
// REVEAL HEADER
// ─────────────────────────────────────────────

class _RevealHeader extends StatelessWidget {
  const _RevealHeader({required this.gameType});
  final String gameType;

  String get _emoji => switch (gameType) {
    'would_you_rather' => '🤔',
    'islamic_trivia'   => '📚',
    'geography_race'   => '🌍',
    _                  => '✨',
  };

  String get _title => switch (gameType) {
    'would_you_rather' => 'Both answered!',
    'islamic_trivia'   => 'Answers revealed!',
    'geography_race'   => 'Race results!',
    _                  => 'Reveal!',
  };

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(_emoji, style: const TextStyle(fontSize: 52)),
      const SizedBox(height: 12),
      Text(_title,
          style: AppTypography.headlineMedium.copyWith(
            color:      AppColors.white,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center),
    ]);
  }
}

// ─────────────────────────────────────────────
// ANSWER CARD
// ─────────────────────────────────────────────

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({
    required this.label,
    required this.answer,
    required this.isMe,
    required this.showCorrect,
    this.isCorrect,
  });
  final String  label;
  final String  answer;
  final bool    isMe;
  final bool    showCorrect;
  final bool?   isCorrect;

  Color get _borderColor {
    if (!showCorrect || isCorrect == null) {
      return isMe
          ? AppColors.roseDeep.withOpacity(0.6)
          : AppColors.neutral300;
    }
    return isCorrect! ? AppColors.success : AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        isMe
            ? AppColors.roseDeep.withOpacity(0.15)
            : Colors.white.withOpacity(0.1),
        borderRadius: AppRadius.cardRadius,
        border:       Border.all(color: _borderColor, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(label,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.white.withOpacity(0.7))),
            const Spacer(),
            if (showCorrect && isCorrect != null)
              Icon(
                isCorrect! ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: isCorrect! ? AppColors.success : AppColors.error,
                size: 18,
              ),
          ]),
          const SizedBox(height: 10),
          Text(
            answer,
            style: AppTypography.bodyLarge.copyWith(
              color:      AppColors.white,
              fontWeight: FontWeight.w600,
              height:     1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CORRECT ANSWER BANNER
// ─────────────────────────────────────────────

class _CorrectAnswerBanner extends StatelessWidget {
  const _CorrectAnswerBanner({required this.answer});
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        AppColors.success.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.success.withOpacity(0.5)),
      ),
      child: Row(children: [
        const Icon(Icons.lightbulb_rounded,
            color: AppColors.success, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Correct answer:',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.success.withOpacity(0.8))),
            Text(answer,
                style: AppTypography.bodyMedium.copyWith(
                  color:      AppColors.white,
                  fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// SCORE BANNER
// ─────────────────────────────────────────────

class _ScoreBanner extends StatelessWidget {
  const _ScoreBanner({required this.scores});
  final Map<String, dynamic> scores;

  @override
  Widget build(BuildContext context) {
    final me   = scores['you']  as int? ?? 0;
    final them = scores['them'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color:        AppColors.goldPrimary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.goldPrimary.withOpacity(0.4)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _ScorePill(label: 'You', score: me),
        const SizedBox(width: 8),
        Text('vs',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.white.withOpacity(0.6))),
        const SizedBox(width: 8),
        _ScorePill(label: 'Them', score: them),
      ]),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.label, required this.score});
  final String label;
  final int    score;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text('$score',
          style: AppTypography.headlineMedium.copyWith(
            color: AppColors.goldLight, fontWeight: FontWeight.w700)),
      Text(label,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.white.withOpacity(0.7))),
    ]);
  }
}

// ─────────────────────────────────────────────
// OUTCOME MESSAGE  (Would You Rather)
// ─────────────────────────────────────────────

class _OutcomeMessage extends StatelessWidget {
  const _OutcomeMessage({required this.sameAnswer});
  final bool sameAnswer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        AppColors.white.withOpacity(0.08),
        borderRadius: AppRadius.cardRadius,
      ),
      child: Row(children: [
        Text(sameAnswer ? '💚' : '🌙',
            style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            sameAnswer
                ? 'You both chose the same! Masha\'Allah — great minds think alike. 🌿'
                : 'Interesting — you chose differently. '
                  'What a wonderful conversation starter!',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.white, height: 1.5),
          ),
        ),
      ]),
    );
  }
}
