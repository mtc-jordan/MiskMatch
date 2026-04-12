import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/game_models.dart';
import '../providers/game_providers.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/shared/widgets/common_widgets.dart';
import 'package:miskmatch/l10n/generated/app_localizations.dart';

/// Time Capsule — special game with 3 distinct states:
///
///   WRITING   — both write letters to future selves
///   SEALED    — locked with countdown timer
///   OPEN      — beautiful reveal of both letters

class TimeCapsuleWidget extends ConsumerStatefulWidget {
  const TimeCapsuleWidget({
    super.key,
    required this.gameState,
    required this.args,
  });

  final GameState gameState;
  final ({String matchId, String gameType}) args;

  @override
  ConsumerState<TimeCapsuleWidget> createState() =>
      _TimeCapsuleWidgetState();
}

class _TimeCapsuleWidgetState extends ConsumerState<TimeCapsuleWidget> {
  final _letterCtrl = TextEditingController();
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    final gs = widget.gameState;
    if (gs.sealed && gs.opensAt != null) {
      _tick();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  void _tick() {
    final gs = widget.gameState;
    if (gs.opensAt == null) return;
    final diff = gs.opensAt!.toUtc().difference(DateTime.now().toUtc());
    if (mounted) {
      setState(() => _remaining = diff.isNegative ? Duration.zero : diff);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _letterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final play = ref.watch(gamePlayProvider(widget.args));
    final gs   = play.gameState ?? widget.gameState;

    if (gs.canOpen) {
      return _OpenState(args: widget.args, play: play);
    }
    if (gs.sealed) {
      return _SealedState(remaining: _remaining, opensAt: gs.opensAt);
    }

    return _WritingState(
      controller:   _letterCtrl,
      isSubmitting: play.isSubmitting,
      onSeal: () async {
        final text = _letterCtrl.text.trim();
        if (text.length < 50) return;
        HapticFeedback.mediumImpact();
        await ref.read(gamePlayProvider(widget.args).notifier)
            .submitTurn(text);
        await ref.read(gamePlayProvider(widget.args).notifier)
            .sealCapsule();
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
// WRITING STATE
// 💌 90px gold circle, spring scale, gold glow
// ═══════════════════════════════════════════════════════════

class _WritingState extends StatefulWidget {
  const _WritingState({
    required this.controller,
    required this.isSubmitting,
    required this.onSeal,
  });
  final TextEditingController controller;
  final bool                  isSubmitting;
  final VoidCallback          onSeal;

  @override
  State<_WritingState> createState() => _WritingStateState();
}

class _WritingStateState extends State<_WritingState> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final charCount = widget.controller.text.trim().length;
    final canSeal   = charCount >= 50;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        children: [
          // ── Header: 💌 in 90px gold circle ──────────────
          Center(
            child: Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                shape:    BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color:      AppColors.goldPrimary.withOpacity(0.3),
                    blurRadius: 20,
                    offset:     const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Text('💌', style: TextStyle(fontSize: 40)),
              ),
            )
                .animate()
                .scale(
                  begin:    const Offset(0.5, 0.5),
                  end:      const Offset(1.0, 1.0),
                  duration: 600.ms,
                  curve:    Curves.elasticOut,
                ),
          ),

          const SizedBox(height: 18),

          // Title + subtitle
          const Text(
            'Time Capsule',
            style: TextStyle(
              fontFamily:  'Georgia',
              fontSize:    26,
              fontWeight:  FontWeight.w700,
              color:       AppColors.goldDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'A letter to your future selves',
            style: AppTypography.bodySmall.copyWith(
              color:     AppColors.neutral500,
              fontStyle: FontStyle.italic,
            ),
          ),

          const SizedBox(height: 24),

          // ── Instruction card ────────────────────────────
          Container(
            width:   double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:        AppColors.goldPrimary.withOpacity(0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.goldPrimary.withOpacity(0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🤲', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Write a letter to your future selves — your hopes '
                    "for this relationship, a du'a, a dream, or a message "
                    'you want to read together on Day 21. Your partner '
                    'will write theirs too. Neither of you can read them '
                    'until the capsule opens.',
                    style: AppTypography.bodySmall.copyWith(
                      color:  AppColors.neutral700,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ).animate(delay: 100.ms).fadeIn(duration: 400.ms),

          const SizedBox(height: 20),

          // ── Letter text area ────────────────────────────
          TextFormField(
            controller: widget.controller,
            maxLines:   10,
            minLines:   6,
            maxLength:  1000,
            decoration: InputDecoration(
              hintText: "Bismillah... dear future us,\n\n"
                  "By the time you read this...",
              hintStyle: AppTypography.bodyMedium.copyWith(
                color:     AppColors.goldLight.withOpacity(0.6),
                fontStyle: FontStyle.italic,
              ),
              alignLabelWithHint: true,
              filled:    true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: AppColors.neutral300.withOpacity(0.4)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: AppColors.neutral300.withOpacity(0.4)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.goldPrimary, width: 2),
              ),
            ),
            style: AppTypography.bodyMedium.copyWith(
              color:  context.onSurface,
              height: 1.6,
            ),
          ).animate(delay: 200.ms).fadeIn(duration: 400.ms),

          const SizedBox(height: 8),

          // ── Character progress + seal readiness ─────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AnimatedSwitcher(
                duration: 200.ms,
                child: canSeal
                    ? Text('✓ Ready to seal',
                        key: const ValueKey('ready'),
                        style: AppTypography.labelSmall.copyWith(
                          color:      AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : Text(
                        '${50 - charCount} more characters to seal',
                        key: const ValueKey('counting'),
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.neutral500),
                      ),
              ),
              Text('$charCount / 1000',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.neutral500),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // ── Seal button ─────────────────────────────────
          MiskButton(
            label:     '🕋 Seal the Capsule',
            onPressed: canSeal && !widget.isSubmitting
                ? widget.onSeal
                : null,
            loading:   widget.isSubmitting,
            variant:   MiskButtonVariant.gold,
          ).animate(delay: 300.ms).fadeIn(duration: 400.ms),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// SEALED STATE — countdown timer, gold pulsing capsule
// nightGradient bg, Quran ayah
// ═══════════════════════════════════════════════════════════

class _SealedState extends StatelessWidget {
  const _SealedState({required this.remaining, required this.opensAt});
  final Duration  remaining;
  final DateTime? opensAt;

  @override
  Widget build(BuildContext context) {
    final d = remaining.inDays;

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.nightGradient,
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Gold pulsing capsule ────────────────────
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  shape:    BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color:      AppColors.goldPrimary.withOpacity(0.3),
                      blurRadius: 24,
                      offset:     const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('🕰️', style: TextStyle(fontSize: 52)),
                ),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(begin: 1.0, end: 1.04, duration: 2500.ms),

              const SizedBox(height: 28),

              const Text(
                'Time Capsule — Sealed',
                style: TextStyle(
                  fontFamily:  'Georgia',
                  fontSize:    26,
                  fontWeight:  FontWeight.w700,
                  color:       AppColors.goldDark,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 10),

              Text(
                'Your letters are safely sealed. '
                'They will be revealed together on Day 21.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color:  AppColors.neutral500,
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 36),

              // ── Countdown display ──────────────────────
              Container(
                width:   double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 24),
                decoration: BoxDecoration(
                  color:        AppColors.goldPrimary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.goldPrimary.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Text('Opens in',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.neutral500),
                    ),
                    const SizedBox(height: 14),

                    if (d >= 1) ...[
                      // Large day count
                      Text(
                        '$d',
                        style: const TextStyle(
                          fontFamily:  'Georgia',
                          fontSize:    72,
                          fontWeight:  FontWeight.w700,
                          color:       AppColors.goldPrimary,
                        ),
                      ),
                      Text(
                        d == 1 ? S.of(context)!.day : S.of(context)!.days,
                        style: const TextStyle(
                          fontSize: 16,
                          color:    AppColors.neutral500,
                        ),
                      ),
                    ] else ...[
                      // HH : MM : SS blocks
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _CountdownBlock(
                            value: _pad(remaining.inHours.remainder(24)),
                            label: S.of(context)!.hours,
                          ),
                          const _ColonSep(),
                          _CountdownBlock(
                            value: _pad(remaining.inMinutes.remainder(60)),
                            label: S.of(context)!.min,
                          ),
                          const _ColonSep(),
                          _CountdownBlock(
                            value: _pad(remaining.inSeconds.remainder(60)),
                            label: S.of(context)!.sec,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // ── Opens [date] caption ───────────────────
              if (opensAt != null) ...[
                const SizedBox(height: 14),
                Text(
                  'Opens ${_formatDate(opensAt!)}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.neutral500),
                ),
              ],

              const SizedBox(height: 36),

              // ── Quran ayah ─────────────────────────────
              const ArabicText(
                'وَعَسَى أَن تَكْرَهُوا شَيْئًا وَهُوَ خَيْرٌ لَّكُمْ',
                style: TextStyle(
                  fontFamily: 'Scheherazade',
                  fontSize:   16,
                  color:      AppColors.goldPrimary,
                  height:     2.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '"Perhaps you dislike a thing and it is good for you." — 2:216',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(
                  color:     AppColors.neutral500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

class _CountdownBlock extends StatelessWidget {
  const _CountdownBlock({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily:  'Georgia',
            fontSize:    40,
            fontWeight:  FontWeight.w700,
            color:       AppColors.goldPrimary,
          ),
        ),
        Text(label,
          style: const TextStyle(
            fontSize: 9,
            color:    AppColors.neutral500,
          ),
        ),
      ],
    );
  }
}

class _ColonSep extends StatelessWidget {
  const _ColonSep();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, left: 6, right: 6),
      child: Text(':',
        style: TextStyle(
          fontFamily:  'Georgia',
          fontSize:    40,
          fontWeight:  FontWeight.w700,
          color:       AppColors.goldPrimary.withOpacity(0.6),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// OPEN STATE — celebration header, letter cards
// ═══════════════════════════════════════════════════════════

class _OpenState extends ConsumerWidget {
  const _OpenState({
    required this.args,
    required this.play,
  });
  final ({String matchId, String gameType}) args;
  final GamePlayState play;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gs = play.gameState;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Celebration header ──────────────────────────
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
                const Text('✨🕰️✨', style: TextStyle(fontSize: 36))
                    .animate()
                    .scale(
                      begin:    const Offset(0.4, 0.4),
                      end:      const Offset(1.0, 1.0),
                      duration: 700.ms,
                      curve:    Curves.elasticOut,
                    ),
                const SizedBox(height: 14),
                const Text(
                  'Your Time Capsule is Open!',
                  style: TextStyle(
                    fontFamily:  'Georgia',
                    fontSize:    26,
                    fontWeight:  FontWeight.w700,
                    color:       AppColors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Read your letters to each other.',
                  style: TextStyle(
                    fontSize: 14,
                    color:    AppColors.white.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 500.ms),

          const SizedBox(height: 28),

          // ── Letter cards ────────────────────────────────
          if (gs != null && gs.turnsHistory.isNotEmpty)
            ...gs.turnsHistory.indexed.map((e) {
              final i    = e.$1;
              final turn = e.$2;
              final ans  = turn['answer']    as String? ?? '';
              final isMe = turn['is_me']     as bool?   ?? (i == 0);
              final name = turn['user_name'] as String? ??
                  (isMe ? 'Your letter' : 'Their letter');

              return Container(
                margin:  const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isMe
                      ? AppColors.roseDeep.withOpacity(0.08)
                      : AppColors.neutral100.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isMe
                        ? AppColors.roseDeep.withOpacity(0.25)
                        : AppColors.neutral300.withOpacity(0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: emoji + name
                    Row(
                      children: [
                        Text(isMe ? '📝' : '💌',
                          style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Text(name,
                          style: AppTypography.titleSmall.copyWith(
                            color: isMe
                                ? AppColors.roseDeep
                                : AppColors.neutral700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Letter text
                    Text(ans,
                      style: AppTypography.bodyMedium.copyWith(
                        color:  context.onSurface,
                        fontSize: 14,
                        height: 1.7,
                      ),
                    ),
                  ],
                ),
              )
                  .animate(delay: Duration(milliseconds: 300 + i * 200))
                  .fadeIn(duration: 500.ms)
                  .slideY(begin: 0.08, end: 0, duration: 500.ms,
                      curve: Curves.easeOutCubic);
            })
          else
            Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  const Text('💌', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 16),
                  Text('The capsule is open!',
                    style: const TextStyle(
                      fontFamily:  'Georgia',
                      fontSize:    20,
                      fontWeight:  FontWeight.w600,
                      color:       AppColors.neutral700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your letters will appear here once processed.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.neutral500),
                  ),
                ],
              ),
            ),

          // Open capsule button
          if (gs?.canOpen == true && gs?.turnsHistory.isEmpty == true) ...[
            const SizedBox(height: 16),
            MiskButton(
              label:     'Open the Time Capsule 🔓',
              onPressed: play.isSubmitting
                  ? null
                  : () => ref
                      .read(gamePlayProvider(args).notifier)
                      .openCapsule(),
              loading:   play.isSubmitting,
              variant:   MiskButtonVariant.gold,
              icon:      Icons.lock_open_rounded,
            ),
          ],
        ],
      ),
    );
  }
}
