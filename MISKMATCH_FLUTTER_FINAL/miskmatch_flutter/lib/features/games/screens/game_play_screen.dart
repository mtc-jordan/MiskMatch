import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/game_models.dart';
import '../providers/game_providers.dart';
import '../widgets/reveal_overlay.dart';
import '../widgets/time_capsule_widget.dart';
import '../widgets/question_view.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/shared/widgets/common_widgets.dart';

/// Unified game player — routes to the correct interaction mode
/// based on GameMode from the catalogue:
///
///   asyncTurn   → QuestionView + submit answer
///   realTime    → QuestionView + submit + WaitingOverlay + RevealOverlay
///   collaborative→ QuestionView (both sides)
///   timerSealed → TimeCapsuleWidget

class GamePlayScreen extends ConsumerWidget {
  const GamePlayScreen({
    super.key,
    required this.matchId,
    required this.gameType,
  });

  final String matchId;
  final String gameType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args  = (matchId: matchId, gameType: gameType);
    final play  = ref.watch(gamePlayProvider(args));
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildAppBar(context, play),
              SliverToBoxAdapter(
                child: _buildBody(context, ref, play, args),
              ),
            ],
          ),
          // Real-time reveal overlay
          if (play.showReveal && play.lastResult != null)
            RevealOverlay(
              result:   play.lastResult!,
              gameType: gameType,
              onDismiss:() => ref
                  .read(gamePlayProvider(args).notifier)
                  .dismissReveal(),
            ),
          // Waiting for partner
          if (play.waitingPartner)
            const _WaitingOverlay(),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, GamePlayState play) {
    final gs    = play.gameState;
    final name  = gs?.name ?? _defaultName(gameType);
    final icon  = gs?.icon ?? '🎮';
    final theme = Theme.of(context);

    return SliverAppBar(
      pinned:          true,
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation:       0,
      leading:         const BackButton(),
      title: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(name,
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.roseDeep),
              overflow: TextOverflow.ellipsis),
        ),
      ]),
      bottom: gs != null
          ? PreferredSize(
              preferredSize: const Size.fromHeight(4),
              child: LinearProgressIndicator(
                value:           gs.progressFraction,
                backgroundColor: AppColors.roseLight.withOpacity(0.3),
                valueColor:      const AlwaysStoppedAnimation(AppColors.roseDeep),
                minHeight:       3,
              ),
            )
          : null,
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref,
      GamePlayState play, ({String matchId, String gameType}) args) {
    if (play.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(60),
        child:   Center(child: CircularProgressIndicator(
            color: AppColors.roseDeep, strokeWidth: 2)),
      );
    }

    if (play.error != null) {
      return _ErrorBody(
        message: play.error!.message,
        onRetry: () => ref.read(gamePlayProvider(args).notifier).load(),
      );
    }

    final gs = play.gameState;
    if (gs == null) {
      return _NotStarted(
        gameType: gameType,
        onStart:  () => ref.read(gamePlayProvider(args).notifier).startGame(),
      );
    }

    // Time Capsule — special widget
    if (gameType == 'time_capsule') {
      return TimeCapsuleWidget(
        gameState: gs,
        args:      args,
      );
    }

    // Completed
    if (gs.status.isDone) {
      return _CompletedBody(
        gameState: gs,
        history:   gs.turnsHistory,
      );
    }

    // Not my turn
    if (!gs.myTurn) {
      return _WaitingTurnBody(gameState: gs);
    }

    // My turn — show question
    final q = gs.currentQuestion;
    if (q == null) {
      return const _NoQuestionBody();
    }

    return QuestionView(
      question:  q,
      gameType:  gameType,
      gameState: gs,
      isSubmitting: play.isSubmitting,
      onSubmitAsync: (answer, {answerData}) => ref
          .read(gamePlayProvider(args).notifier)
          .submitTurn(answer, answerData: answerData),
      onSubmitRealtime: (questionId, answer) => ref
          .read(gamePlayProvider(args).notifier)
          .submitRealtime(questionId, answer),
    );
  }

  String _defaultName(String t) => switch (t) {
    'qalb_quiz'        => 'Qalb Quiz',
    'would_you_rather' => 'Would You Rather',
    'finish_sentence'  => 'Finish My Sentence',
    'values_map'       => 'Values Map',
    'islamic_trivia'   => 'Islamic Trivia',
    'quran_ayah'       => 'Quran Ayah',
    'geography_race'   => 'Geography Race',
    'hadith_match'     => 'Hadith Match',
    'build_story'      => 'Build Our Story',
    'dream_home'       => 'Dream Home',
    'time_capsule'     => 'Time Capsule',
    'honesty_box'      => 'Honesty Box',
    'priority_rank'    => 'Priority Ranking',
    'love_languages'   => 'Love Languages',
    'thirty_six_questions' => '36 Questions',
    'family_trivia'    => 'Family Trivia',
    'deal_no_deal'     => 'Deal or No Deal',
    _                  => 'Game',
  };
}

// ─────────────────────────────────────────────
// NOT STARTED
// ─────────────────────────────────────────────

class _NotStarted extends StatelessWidget {
  const _NotStarted({required this.gameType, required this.onStart});
  final String            gameType;
  final Future<bool> Function() onStart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Text('🌙', style: const TextStyle(fontSize: 64))
              .animate().scale(begin: const Offset(0.6, 0.6),
                  duration: 500.ms, curve: Curves.elasticOut),
          const SizedBox(height: 24),
          Text('Ready to begin?',
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.neutral900),
              textAlign: TextAlign.center)
              .animate(delay: 200.ms).fadeIn(),
          const SizedBox(height: 10),
          Text(
            'This game will help you and your match discover each other '
            "through meaningful questions. Answer honestly — your wali can see all responses.",
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.neutral500, height: 1.6),
          ).animate(delay: 300.ms).fadeIn(),
          const SizedBox(height: 36),
          MiskButton(
            label:     'Start — Bismillah',
            onPressed: onStart,
            icon:      Icons.play_arrow_rounded,
          ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.1, end: 0),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// WAITING FOR TURN
// ─────────────────────────────────────────────

class _WaitingTurnBody extends StatelessWidget {
  const _WaitingTurnBody({required this.gameState});
  final GameState gameState;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          const Text('⏳', style: TextStyle(fontSize: 56))
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 1.0, end: 1.1, duration: 1500.ms),
          const SizedBox(height: 24),
          Text('Waiting for your match',
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.neutral700),
              textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(
            'They have been notified. '
            "You'll receive a notification when it's your turn.",
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.neutral500, height: 1.6),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:        AppColors.roseDeep.withOpacity(0.05),
              borderRadius: AppRadius.cardRadius,
            ),
            child: Row(children: [
              const Icon(Icons.history_toggle_off_rounded,
                  color: AppColors.roseDeep, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Turn ${gameState.turnNumber} of ${gameState.totalTurns}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.roseDeep),
                ),
              ),
              Text(gameState.progress,
                  style: AppTypography.labelMedium.copyWith(
                    color:      AppColors.roseDeep,
                    fontWeight: FontWeight.w600,
                  )),
            ]),
          ),
        ],
      ),
    );
  }

  String get progress =>
      '${gameState.turnNumber}/${gameState.totalTurns}';
}

extension on GameState {
  String get progress => '$turnNumber/$totalTurns';
}

// ─────────────────────────────────────────────
// COMPLETED
// ─────────────────────────────────────────────

class _CompletedBody extends StatelessWidget {
  const _CompletedBody({required this.gameState, required this.history});
  final GameState                      gameState;
  final List<Map<String, dynamic>>     history;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Completion banner
          Container(
            width:   double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient:     AppColors.goldGradient,
              borderRadius: AppRadius.cardRadius,
              boxShadow:    AppShadows.elevated,
            ),
            child: Column(children: [
              const Text('✨', style: TextStyle(fontSize: 40))
                  .animate().scale(
                      begin:  const Offset(0.5, 0.5),
                      duration: 600.ms,
                      curve:  Curves.elasticOut),
              const SizedBox(height: 12),
              Text('Masha\'Allah — Game Complete!',
                  style: AppTypography.headlineSmall.copyWith(
                    color:      AppColors.white,
                    fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center),
              Text(
                'Added to your Match Memory.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.white.withOpacity(0.85)),
              ),
            ]),
          ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.05, end: 0),

          const SizedBox(height: 24),
          Text('Turn History',
              style: AppTypography.titleMedium),
          const SizedBox(height: 12),

          // Turn history
          ...history.indexed.map((e) {
            final i    = e.$1;
            final turn = e.$2;
            final q    = turn['question'] as Map<String, dynamic>?;
            final ans  = turn['answer']   as String? ?? '';
            final uid  = turn['user_id']  as String? ?? '';

            return MiskCard(
              margin:  const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              child:   Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color:        AppColors.roseDeep.withOpacity(0.08),
                        borderRadius: AppRadius.chipRadius,
                      ),
                      child: Text('Turn ${i + 1}',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.roseDeep)),
                    ),
                  ]),
                  if (q != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      q['text'] as String? ??
                      q['stem'] as String? ??
                      q['q']    as String? ?? '',
                      style: AppTypography.bodySmall.copyWith(
                        color:     AppColors.neutral500,
                        fontStyle: FontStyle.italic),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(ans,
                      style: AppTypography.bodyMedium.copyWith(
                        color:      AppColors.neutral900,
                        fontWeight: FontWeight.w500,
                      )),
                ],
              ),
            )
                .animate(delay: Duration(milliseconds: i * 40))
                .fadeIn(duration: 300.ms)
                .slideY(begin: 0.03, end: 0);
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// WAITING OVERLAY  (real-time — submitted, waiting)
// ─────────────────────────────────────────────

class _WaitingOverlay extends StatelessWidget {
  const _WaitingOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.55),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          margin:  const EdgeInsets.symmetric(horizontal: 40),
          decoration: BoxDecoration(
            color:        Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⏳', style: TextStyle(fontSize: 52))
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(begin: 1.0, end: 1.1, duration: 1200.ms),
              const SizedBox(height: 20),
              Text("Waiting for your match's answer...",
                  textAlign: TextAlign.center,
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.neutral900)),
              const SizedBox(height: 8),
              Text('Both answers are hidden until you both answer.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.neutral500)),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ─────────────────────────────────────────────
// ERROR / NO QUESTION
// ─────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});
  final String       message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline_rounded,
            size: 48, color: AppColors.neutral300),
        const SizedBox(height: 20),
        Text(message, textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.neutral500)),
        const SizedBox(height: 24),
        MiskButton(label: 'Retry', onPressed: onRetry,
            variant: MiskButtonVariant.outline, fullWidth: false),
      ]),
    );
  }
}

class _NoQuestionBody extends StatelessWidget {
  const _NoQuestionBody();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🌙', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 16),
        Text('No more questions',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.neutral700),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('This game is wrapping up!',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.neutral500)),
      ]),
    );
  }
}
