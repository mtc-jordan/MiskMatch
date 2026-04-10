import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
///   t=0:    Scrim fades in (250ms)
///   t=200:  Header emoji scales in elasticOut (52pt, 600ms)
///   t=400:  "Both answered!" white bold Georgia 28pt, fadeIn + slideY
///   t=500:  My answer card slides from left (300ms easeOutCubic)
///   t=650:  Their answer card slides from right (300ms easeOutCubic)
///   t=800:  Correct answer banner (trivia only) slides up (300ms)
///   t=900:  Score banner fades in
///   t=1000: Dismiss button fades in

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
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth   = (screenWidth - 56) / 2; // 24px padding each side + 8px gap

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
                // ── t=200: Header emoji ──────────────────────
                Text(_emoji, style: const TextStyle(fontSize: 52))
                    .animate(delay: 200.ms)
                    .scale(
                      begin: const Offset(0.4, 0.4),
                      end:   const Offset(1.0, 1.0),
                      duration: 600.ms,
                      curve: Curves.elasticOut,
                    ),

                const SizedBox(height: 14),

                // ── t=400: Title ─────────────────────────────
                Text(
                  _title,
                  style: const TextStyle(
                    fontFamily:  'Georgia',
                    fontSize:    28,
                    fontWeight:  FontWeight.w700,
                    color:       AppColors.white,
                  ),
                  textAlign: TextAlign.center,
                ).animate(delay: 400.ms)
                 .fadeIn(duration: 400.ms)
                 .slideY(begin: 0.1, end: 0, duration: 400.ms,
                     curve: Curves.easeOutCubic),

                const SizedBox(height: 32),

                // ── t=500/650: Answer cards side by side ─────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // My answer — slides from left
                    SizedBox(
                      width: cardWidth,
                      child: _AnswerCard(
                        label:       'Your answer',
                        answer:      result.yourAnswer ?? '—',
                        isMe:        true,
                        isCorrect:   result.youGotIt,
                        showCorrect: _isTrivia,
                      ).animate(delay: 500.ms)
                       .fadeIn(duration: 300.ms)
                       .slideX(begin: -0.2, end: 0,
                           duration: 300.ms,
                           curve: Curves.easeOutCubic),
                    ),

                    const SizedBox(width: 8),

                    // Their answer — slides from right
                    SizedBox(
                      width: cardWidth,
                      child: _AnswerCard(
                        label:       'Their answer',
                        answer:      result.partnerAnswer ?? '—',
                        isMe:        false,
                        isCorrect:   result.theyGotIt,
                        showCorrect: _isTrivia,
                      ).animate(delay: 650.ms)
                       .fadeIn(duration: 300.ms)
                       .slideX(begin: 0.2, end: 0,
                           duration: 300.ms,
                           curve: Curves.easeOutCubic),
                    ),
                  ],
                ),

                // ── t=800: Correct answer banner (trivia) ───
                if (_isTrivia && result.correctAnswer != null) ...[
                  const SizedBox(height: 20),
                  _CorrectAnswerBanner(answer: result.correctAnswer!)
                      .animate(delay: 800.ms)
                      .fadeIn(duration: 300.ms)
                      .slideY(begin: 0.15, end: 0,
                          duration: 300.ms,
                          curve: Curves.easeOutCubic),
                ],

                // ── Outcome message (WYR — same/different) ──
                if (!_isTrivia) ...[
                  const SizedBox(height: 20),
                  _OutcomeMessage(
                    sameAnswer: result.yourAnswer == result.partnerAnswer,
                  ).animate(delay: 800.ms)
                   .fadeIn(duration: 400.ms),
                ],

                // ── t=900: Score banner ──────────────────────
                if (result.scores != null &&
                    result.scores!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _ScoreBanner(scores: result.scores!)
                      .animate(delay: 900.ms)
                      .fadeIn(duration: 300.ms),
                ],

                const SizedBox(height: 36),

                // ── t=1000: Dismiss button ───────────────────
                MiskButton(
                  label: result.gameComplete
                      ? "Masha'Allah — Game complete! 🌙"
                      : 'Next question →',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onDismiss();
                  },
                  variant: result.gameComplete
                      ? MiskButtonVariant.gold
                      : MiskButtonVariant.primary,
                  icon: result.gameComplete
                      ? Icons.celebration_rounded
                      : Icons.arrow_forward_rounded,
                ).animate(delay: 1000.ms)
                 .fadeIn(duration: 400.ms),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 250.ms);
  }

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
}

// ─────────────────────────────────────────────
// ANSWER CARD
// Mine: roseDeep 15% bg, 2px roseDeep border
// Theirs: white 10% bg, 2px neutral500 border
// Min height 130px, 16px radius
// Trivia correct: green border + ✓
// Trivia wrong: red border + ✗
// ─────────────────────────────────────────────

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({
    required this.label,
    required this.answer,
    required this.isMe,
    required this.showCorrect,
    this.isCorrect,
  });
  final String label;
  final String answer;
  final bool   isMe;
  final bool   showCorrect;
  final bool?  isCorrect;

  Color get _borderColor {
    if (showCorrect && isCorrect != null) {
      return isCorrect! ? AppColors.success : AppColors.error;
    }
    return isMe ? AppColors.roseDeep : AppColors.neutral500;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 130),
      padding:     const EdgeInsets.all(16),
      decoration:  BoxDecoration(
        color: isMe
            ? AppColors.roseDeep.withOpacity(0.15)
            : Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label + correctness icon
          Row(
            children: [
              Text(label,
                style: TextStyle(
                  fontSize: 9,
                  color:    AppColors.white.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (showCorrect && isCorrect != null)
                Icon(
                  isCorrect!
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  color: isCorrect! ? AppColors.success : AppColors.error,
                  size:  18,
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Answer text
          Text(
            answer,
            style: const TextStyle(
              fontSize:   15,
              fontWeight: FontWeight.w700,
              color:      AppColors.white,
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
// success 15% bg, success border, 💡 icon
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.success.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Text('💡', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Correct: ',
                    style: TextStyle(
                      fontSize:   13,
                      color:      AppColors.success.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextSpan(
                    text: answer,
                    style: const TextStyle(
                      fontSize:   14,
                      color:      AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SCORE BANNER
// gold 15% bg, gold border
// "You: X  vs  Them: Y" — gold 36pt Georgia
// ─────────────────────────────────────────────

class _ScoreBanner extends StatelessWidget {
  const _ScoreBanner({required this.scores});
  final Map<String, dynamic> scores;

  @override
  Widget build(BuildContext context) {
    final me   = scores['you']  as int? ?? 0;
    final them = scores['them'] as int? ?? 0;

    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color:        AppColors.goldPrimary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.goldPrimary.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // You score
          Column(
            children: [
              Text(
                '$me',
                style: const TextStyle(
                  fontFamily:  'Georgia',
                  fontSize:    36,
                  fontWeight:  FontWeight.w700,
                  color:       AppColors.goldLight,
                ),
              ),
              Text('You',
                style: TextStyle(
                  fontSize: 11,
                  color:    AppColors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('vs',
              style: TextStyle(
                fontSize: 14,
                color:    AppColors.white.withOpacity(0.5),
              ),
            ),
          ),

          // Them score
          Column(
            children: [
              Text(
                '$them',
                style: const TextStyle(
                  fontFamily:  'Georgia',
                  fontSize:    36,
                  fontWeight:  FontWeight.w700,
                  color:       AppColors.goldLight,
                ),
              ),
              Text('Them',
                style: TextStyle(
                  fontSize: 11,
                  color:    AppColors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// OUTCOME MESSAGE (Would You Rather)
// Same: 💚 "You both chose the same! Masha'Allah"
// Different: 🌙 "You chose differently"
// ─────────────────────────────────────────────

class _OutcomeMessage extends StatelessWidget {
  const _OutcomeMessage({required this.sameAnswer});
  final bool sameAnswer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        AppColors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text(
            sameAnswer ? '💚' : '🌙',
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              sameAnswer
                  ? "You both chose the same! Masha'Allah"
                  : 'You chose differently — great conversation starter!',
              style: const TextStyle(
                fontSize: 14,
                color:    AppColors.white,
                height:   1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
