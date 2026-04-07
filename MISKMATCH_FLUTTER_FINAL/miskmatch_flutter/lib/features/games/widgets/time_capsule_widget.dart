import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/game_models.dart';
import '../providers/game_providers.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/shared/widgets/common_widgets.dart';

/// Time Capsule — special game with 3 distinct states:
///
///   WRITING   — both write letters to future selves (open_text input)
///   SEALED    — locked with countdown timer until Day 21
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

    if (gs.canOpen) return _OpenState(args: widget.args, play: play);
    if (gs.sealed)  return _SealedState(remaining: _remaining, opensAt: gs.opensAt);

    // Writing state
    return _WritingState(
      controller:   _letterCtrl,
      isSubmitting: play.isSubmitting,
      onSeal: () async {
        final text = _letterCtrl.text.trim();
        if (text.length < 50) return;
        // Submit the letter first, then seal
        await ref.read(gamePlayProvider(widget.args).notifier)
            .submitTurn(text);
        await ref.read(gamePlayProvider(widget.args).notifier)
            .sealCapsule();
      },
    );
  }
}

// ─────────────────────────────────────────────
// WRITING STATE
// ─────────────────────────────────────────────

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header illustration
          _CapsuleHeader().animate().fadeIn(duration: 500.ms),

          const SizedBox(height: 24),

          // Instructions card
          MiskCard(
            color: AppColors.goldPrimary.withOpacity(0.06),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text('🤲', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text('Dear Future Us',
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.goldDark)),
                ]),
                const SizedBox(height: 8),
                Text(
                  'Write a letter to your future selves — your hopes for this '
                  'relationship, a du\'a, a dream, or a message you want to '
                  'read together on Day 21. Your partner will write theirs '
                  'too. Neither of you can read them until the capsule opens.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.neutral700, height: 1.6),
                ),
              ],
            ),
          ).animate(delay: 100.ms).fadeIn(),

          const SizedBox(height: 20),

          // Letter input
          TextFormField(
            controller: widget.controller,
            maxLines:   10,
            minLines:   6,
            maxLength:  1000,
            decoration: InputDecoration(
              hintText: 'Bismillah... dear future us,\n\n'
                  'By the time you read this, in sha Allah...',
              hintStyle: AppTypography.bodyMedium.copyWith(
                  color: AppColors.neutral400, fontStyle: FontStyle.italic),
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                borderSide: const BorderSide(
                    color: AppColors.goldPrimary, width: 2)),
            ),
            style: AppTypography.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurface, height: 1.6),
          ).animate(delay: 200.ms).fadeIn(),

          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(
              canSeal ? '✓ Ready to seal' : '${50 - charCount} more chars to seal',
              style: AppTypography.labelSmall.copyWith(
                color: canSeal ? AppColors.success : AppColors.neutral500),
            ),
            Text('$charCount / 1000',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.neutral500)),
          ]),

          const SizedBox(height: 24),

          // Seal button
          MiskButton(
            label:     '🕋 Seal the Capsule',
            onPressed: canSeal && !widget.isSubmitting
                ? widget.onSeal : null,
            loading:   widget.isSubmitting,
            variant:   MiskButtonVariant.gold,
          ).animate(delay: 300.ms).fadeIn(),
        ],
      ),
    );
  }
}

extension on AppColors {
  static const neutral400 = Color(0xFFAAAAAA);
}

// ─────────────────────────────────────────────
// SEALED STATE  — countdown timer
// ─────────────────────────────────────────────

class _SealedState extends StatelessWidget {
  const _SealedState({required this.remaining, required this.opensAt});
  final Duration  remaining;
  final DateTime? opensAt;

  String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final d = remaining.inDays;
    final h = _pad(remaining.inHours.remainder(24));
    final m = _pad(remaining.inMinutes.remainder(60));
    final s = _pad(remaining.inSeconds.remainder(60));

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Capsule illustration
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                gradient:     AppColors.goldGradient,
                shape:        BoxShape.circle,
                boxShadow:    AppShadows.elevated,
              ),
              child: const Center(
                child: Text('🕰️', style: TextStyle(fontSize: 52)),
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 1.0, end: 1.04, duration: 2500.ms),

            const SizedBox(height: 28),

            Text('Time Capsule — Sealed',
                style: AppTypography.headlineSmall.copyWith(
                  color: AppColors.goldDark, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),

            const SizedBox(height: 8),

            Text(
              'Your letters are safely sealed. '
              'They will be revealed together on Day 21.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.neutral500, height: 1.6),
            ),

            const SizedBox(height: 32),

            // Countdown display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              decoration: BoxDecoration(
                gradient:     LinearGradient(colors: [
                  AppColors.goldPrimary.withOpacity(0.08),
                  AppColors.roseDeep.withOpacity(0.05),
                ]),
                borderRadius: AppRadius.cardRadius,
                border: Border.all(
                  color: AppColors.goldPrimary.withOpacity(0.3)),
              ),
              child: Column(children: [
                Text('Opens in',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.neutral500)),
                const SizedBox(height: 12),
                // Counter digits
                if (remaining.inDays >= 1) ...[
                  Text('$d',
                      style: AppTypography.displayLarge.copyWith(
                        color:      AppColors.goldPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize:   72,
                      )),
                  Text(d == 1 ? 'day' : 'days',
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.neutral500)),
                ] else ...[
                  Row(mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    _CountdownBlock(value: h, label: 'hr'),
                    const _Sep(),
                    _CountdownBlock(value: m, label: 'min'),
                    const _Sep(),
                    _CountdownBlock(value: s, label: 'sec'),
                  ]),
                ],
              ]),
            ),

            if (opensAt != null) ...[
              const SizedBox(height: 16),
              Text(
                'Opens ${_formatDate(opensAt!)}',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.neutral500),
              ),
            ],

            const SizedBox(height: 28),

            const ArabicText(
              'وَعَسَى أَن تَكْرَهُوا شَيْئًا وَهُوَ خَيْرٌ لَّكُمْ',
              style: TextStyle(
                fontFamily: 'Scheherazade',
                fontSize:   16,
                color:      AppColors.goldPrimary,
                height:     2.0,
              ),
            ),
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
    );
  }

  String _formatDate(DateTime dt) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

class _CountdownBlock extends StatelessWidget {
  const _CountdownBlock({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value,
          style: AppTypography.displayMedium.copyWith(
            color:      AppColors.goldPrimary,
            fontWeight: FontWeight.w700,
            fontSize:   40,
          )),
      Text(label,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.neutral500)),
    ]);
  }
}

class _Sep extends StatelessWidget {
  const _Sep();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
      child: Text(':',
          style: AppTypography.displayMedium.copyWith(
            color:      AppColors.goldPrimary.withOpacity(0.6),
            fontWeight: FontWeight.w700,
            fontSize:   40,
          )),
    );
  }
}

// ─────────────────────────────────────────────
// OPEN STATE  — both letters revealed
// ─────────────────────────────────────────────

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
          // Celebration header
          Container(
            width:   double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient:     AppColors.goldGradient,
              borderRadius: AppRadius.cardRadius,
              boxShadow:    AppShadows.elevated,
            ),
            child: Column(children: [
              const Text('✨🕰️✨', style: TextStyle(fontSize: 36))
                  .animate().scale(
                      begin: const Offset(0.5, 0.5),
                      duration: 700.ms, curve: Curves.elasticOut),
              const SizedBox(height: 12),
              Text('Your Time Capsule is Open!',
                  style: AppTypography.headlineSmall.copyWith(
                    color: AppColors.white, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center),
              Text('Read your letters to each other.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.white.withOpacity(0.85))),
            ]),
          ).animate().fadeIn(duration: 500.ms),

          const SizedBox(height: 28),

          // Letters from history
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
                  gradient: isMe
                      ? LinearGradient(colors: [
                          AppColors.roseDeep.withOpacity(0.08),
                          AppColors.goldPrimary.withOpacity(0.04),
                        ])
                      : LinearGradient(colors: [
                          AppColors.neutral100.withOpacity(0.6),
                          AppColors.roseLight.withOpacity(0.08),
                        ]),
                  borderRadius: AppRadius.cardRadius,
                  border: Border.all(
                    color: isMe
                        ? AppColors.roseDeep.withOpacity(0.2)
                        : AppColors.neutral300.withOpacity(0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(isMe ? '📝' : '💌',
                          style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Text(name,
                          style: AppTypography.titleSmall.copyWith(
                            color: isMe
                                ? AppColors.roseDeep
                                : AppColors.neutral700,
                          )),
                    ]),
                    const SizedBox(height: 14),
                    Text(ans,
                        style: AppTypography.bodyMedium.copyWith(
                          color:  AppColors.neutral900,
                          height: 1.7,
                        )),
                  ],
                ),
              )
                  .animate(delay: Duration(milliseconds: 300 + i * 200))
                  .fadeIn(duration: 500.ms)
                  .slideY(begin: 0.06, end: 0);
            })
          else
            Padding(
              padding: const EdgeInsets.all(40),
              child: Column(children: [
                const Text('💌', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 16),
                Text('The capsule is open!',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.neutral700),
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text('Your letters will appear here once processed.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.neutral500)),
              ]),
            ),

          // Open capsule button (if can_open but not yet opened)
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

// ─────────────────────────────────────────────
// CAPSULE HEADER ILLUSTRATION
// ─────────────────────────────────────────────

class _CapsuleHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        width: 90, height: 90,
        decoration: BoxDecoration(
          gradient:     AppColors.goldGradient,
          shape:        BoxShape.circle,
          boxShadow:    AppShadows.elevated,
        ),
        child: const Center(
          child: Text('💌', style: TextStyle(fontSize: 40)),
        ),
      ),
      const SizedBox(height: 16),
      Text('Time Capsule',
          style: AppTypography.headlineSmall.copyWith(
            color:      AppColors.goldDark,
            fontWeight: FontWeight.w700,
          )),
      Text('A letter to your future selves',
          style: AppTypography.bodySmall.copyWith(
            color:     AppColors.neutral500,
            fontStyle: FontStyle.italic,
          )),
    ]);
  }
}
