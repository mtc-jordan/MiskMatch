import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miskmatch/l10n/generated/app_localizations.dart';
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
/// based on GameMode from the catalogue.

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
    final args = (matchId: matchId, gameType: gameType);
    final play = ref.watch(gamePlayProvider(args));

    return Scaffold(
      backgroundColor: context.scaffoldColor,
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
              result:    play.lastResult!,
              gameType:  gameType,
              onDismiss: () => ref
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
    final gs   = play.gameState;
    final name = gs?.name ?? _defaultName(gameType);
    final icon = gs?.icon ?? '🎮';

    return SliverAppBar(
      pinned:           true,
      backgroundColor:  context.scaffoldColor,
      elevation:        0,
      surfaceTintColor: Colors.transparent,
      leading:          const BackButton(),
      title: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name,
              style: const TextStyle(
                fontFamily:  'Georgia',
                fontSize:    18,
                fontWeight:  FontWeight.w700,
                color:       AppColors.roseDeep,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      bottom: gs != null
          ? PreferredSize(
              preferredSize: const Size.fromHeight(3),
              child: TweenAnimationBuilder<double>(
                tween:    Tween(begin: 0, end: gs.progressFraction),
                duration: 400.ms,
                curve:    Curves.easeOutCubic,
                builder: (_, value, __) => LinearProgressIndicator(
                  value:           value,
                  backgroundColor: AppColors.roseLight.withOpacity(0.3),
                  valueColor: const AlwaysStoppedAnimation(AppColors.roseDeep),
                  minHeight: 3,
                ),
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
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.roseDeep, strokeWidth: 2),
        ),
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
      question:     q,
      gameType:     gameType,
      gameState:    gs,
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
// NOT STARTED — 🌙 spring scale, Georgia 26pt,
// "Start — Bismillah" gold button with 🕌
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
          const SizedBox(height: 60),

          const Text('🌙', style: TextStyle(fontSize: 64))
              .animate()
              .scale(
                begin: const Offset(0.5, 0.5),
                end:   const Offset(1.0, 1.0),
                duration: 600.ms,
                curve: Curves.elasticOut,
              ),

          const SizedBox(height: 28),

          Text(
            S.of(context)!.readyToBegin,
            style: TextStyle(
              fontFamily:  'Georgia',
              fontSize:    26,
              fontWeight:  FontWeight.w700,
              color:       context.onSurface,
            ),
            textAlign: TextAlign.center,
          ).animate(delay: 200.ms).fadeIn(duration: 400.ms),

          const SizedBox(height: 12),

          Text(
            S.of(context)!.gameDescriptionIntro,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color:  context.mutedText,
              height: 1.6,
            ),
          ).animate(delay: 300.ms).fadeIn(duration: 400.ms),

          const SizedBox(height: 40),

          MiskButton(
            label:     S.of(context)!.startBismillah,
            onPressed: onStart,
            variant:   MiskButtonVariant.gold,
            icon:      Icons.mosque_rounded,
          ).animate(delay: 400.ms)
           .fadeIn(duration: 400.ms)
           .slideY(begin: 0.15, end: 0, duration: 400.ms,
               curve: Curves.easeOutCubic),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// WAITING FOR TURN — ⏳ slow pulse, progress chip
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
          const SizedBox(height: 60),

          const Text('⏳', style: TextStyle(fontSize: 56))
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 1.0, end: 1.08, duration: 2000.ms),

          const SizedBox(height: 28),

          Text(
            S.of(context)!.waitingForMatch,
            style: TextStyle(
              fontFamily:  'Georgia',
              fontSize:    22,
              fontWeight:  FontWeight.w600,
              color:       context.subtleText,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 10),

          Text(
            '${S.of(context)!.matchNotified} '
            '${S.of(context)!.notificationOnYourTurn}',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color:  context.mutedText,
              height: 1.6,
            ),
          ),

          const SizedBox(height: 32),

          // Turn progress chip
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color:        AppColors.roseDeep.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.roseDeep.withOpacity(0.12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.history_toggle_off_rounded,
                  color: AppColors.roseDeep, size: 18),
                const SizedBox(width: 8),
                Text(
                  S.of(context)!.turnOf('${gameState.turnNumber}', '${gameState.totalTurns}'),
                  style: AppTypography.labelMedium.copyWith(
                    color:      AppColors.roseDeep,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// COMPLETED — gold celebration, ✨ elastic scale,
// Georgia 26pt, turn history stagger
// ─────────────────────────────────────────────

class _CompletedBody extends StatelessWidget {
  const _CompletedBody({required this.gameState, required this.history});
  final GameState                  gameState;
  final List<Map<String, dynamic>> history;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Gold celebration banner ─────────────────
          Container(
            width:   double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient:     AppColors.goldGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color:      AppColors.goldPrimary.withOpacity(0.25),
                  blurRadius: 16,
                  offset:     const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text('✨', style: TextStyle(fontSize: 48))
                    .animate()
                    .scale(
                      begin:    const Offset(0.4, 0.4),
                      end:      const Offset(1.0, 1.0),
                      duration: 600.ms,
                      curve:    Curves.elasticOut,
                    ),
                const SizedBox(height: 14),
                Text(
                  S.of(context)!.mashAllahComplete,
                  style: const TextStyle(
                    fontFamily:  'Georgia',
                    fontSize:    26,
                    fontWeight:  FontWeight.w700,
                    color:       AppColors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  S.of(context)!.addedToMatchMemory,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.white.withOpacity(0.85)),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 500.ms)
           .slideY(begin: -0.05, end: 0, duration: 500.ms),

          const SizedBox(height: 28),

          // ── Turn History header ─────────────────────
          Text(
            S.of(context)!.turnHistory,
            style: TextStyle(
              fontFamily:  'Georgia',
              fontSize:    18,
              fontWeight:  FontWeight.w700,
              color:       context.onSurface,
            ),
          ),

          const SizedBox(height: 14),

          // ── Turn history cards ──────────────────────
          ...history.indexed.map((e) {
            final i    = e.$1;
            final turn = e.$2;
            final q    = turn['question'] as Map<String, dynamic>?;
            final ans  = turn['answer']   as String? ?? '';

            return Container(
              margin:  const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:        context.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow:    context.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Turn badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color:        AppColors.roseDeep.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text('Turn ${i + 1}',
                      style: AppTypography.labelSmall.copyWith(
                        color:      AppColors.roseDeep,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (q != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      q['text'] as String? ??
                      q['stem'] as String? ??
                      q['q']    as String? ?? '',
                      style: AppTypography.bodySmall.copyWith(
                        color:     context.mutedText,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(ans,
                    style: AppTypography.bodyMedium.copyWith(
                      color:      context.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
                .animate(delay: Duration(milliseconds: i * 40))
                .fadeIn(duration: 300.ms)
                .slideY(begin: 0.03, end: 0, duration: 300.ms,
                    curve: Curves.easeOutCubic);
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// WAITING OVERLAY (real-time — submitted, waiting)
// ─────────────────────────────────────────────

class _WaitingOverlay extends StatelessWidget {
  const _WaitingOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.midnightDeep.withOpacity(0.55),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          margin:  const EdgeInsets.symmetric(horizontal: 40),
          decoration: BoxDecoration(
            color:        context.surfaceColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow:    context.cardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⏳', style: TextStyle(fontSize: 52))
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(begin: 1.0, end: 1.1, duration: 1200.ms),
              const SizedBox(height: 20),
              Text(S.of(context)!.waitingForMatchAnswer,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily:  'Georgia',
                  fontSize:    18,
                  fontWeight:  FontWeight.w600,
                  color:       context.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                S.of(context)!.answersHiddenUntil,
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(
                  color: context.mutedText),
              ),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded,
            size: 48, color: AppColors.neutral300),
          const SizedBox(height: 20),
          Text(message,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: context.mutedText),
          ),
          const SizedBox(height: 24),
          MiskButton(
            label:     S.of(context)!.retry,
            onPressed: onRetry,
            variant:   MiskButtonVariant.outline,
            fullWidth: false,
          ),
        ],
      ),
    );
  }
}

class _NoQuestionBody extends StatelessWidget {
  const _NoQuestionBody();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🌙', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            S.of(context)!.noMoreQuestions,
            style: TextStyle(
              fontFamily:  'Georgia',
              fontSize:    20,
              fontWeight:  FontWeight.w600,
              color:       context.subtleText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(S.of(context)!.gameWrappingUp,
            style: AppTypography.bodyMedium.copyWith(
              color: context.mutedText),
          ),
        ],
      ),
    );
  }
}
