import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/call_models.dart';
import '../providers/call_provider.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/shared/extensions/app_extensions.dart';
import 'package:miskmatch/l10n/generated/app_localizations.dart';

/// Incoming call screen — full-screen takeover with
/// nightGradient bg, concentric pulse rings, and
/// decline/accept buttons.

class RingingScreen extends ConsumerWidget {
  const RingingScreen({
    super.key,
    required this.callerName,
    required this.callType,
    required this.callId,
    required this.participantType,
    required this.myName,
  });

  final String   callerName;
  final CallType callType;
  final String   callId;
  final String   participantType; // "receiver" | "wali"
  final String   myName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.nightGradient,
        ),
        child: Stack(
          children: [
            // ── Background rose circle ─────────────────────
            Positioned(
              top: -80, right: -100,
              child: Container(
                width: 400, height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.roseDeep.withOpacity(0.06),
                ),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveY(begin: 0, end: 12, duration: 4000.ms),
            ),

            // ── Main content ───────────────────────────────
            SafeArea(
              child: Column(
                children: [
                  const Spacer(),

                  // ── Header ─────────────────────────────
                  _CallerInfo(
                    callerName:      callerName,
                    callType:        callType,
                    participantType: participantType,
                  ),

                  const SizedBox(height: 32),

                  // ── Pulse rings + avatar ────────────────
                  _PulseRing(callerName: callerName),

                  const SizedBox(height: 40),

                  // ── Wali note (chaperoned calls) ────────
                  if (callType.isChaperoned)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.goldPrimary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.goldPrimary.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Text('🛡️',
                              style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                participantType == 'wali'
                                    ? 'You have been invited as guardian to this call.'
                                    : 'Your guardian has been invited to join as chaperone.',
                                style: AppTypography.bodySmall.copyWith(
                                  color:  AppColors.goldLight,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate(delay: 300.ms).fadeIn(duration: 400.ms),
                    ),

                  const Spacer(),

                  // ── Action buttons ─────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(48, 0, 48, 48),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Decline — red
                        _CallButton(
                          icon:  Icons.call_end_rounded,
                          color: AppColors.error,
                          label: 'Decline',
                          onTap: () {
                            Haptic.medium();
                            ref.read(callProvider.notifier)
                                .declineCall(callId);
                            Navigator.of(context).pop();
                          },
                        ),

                        // Accept — green
                        _CallButton(
                          icon: callType.isVideo
                              ? Icons.videocam_rounded
                              : Icons.call_rounded,
                          color: AppColors.success,
                          label: 'Accept',
                          onTap: () async {
                            Haptic.confirm();
                            await ref.read(callProvider.notifier).acceptCall(
                              callId:          callId,
                              myName:          myName,
                              participantType: participantType,
                            );
                            if (context.mounted) {
                              Navigator.of(context).pushReplacementNamed(
                                '/call-active',
                                arguments: {
                                  'callId':    callId,
                                  'callType':  callType,
                                  'myName':    myName,
                                  'otherName': callerName,
                                },
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CALLER INFO
// "Incoming call" 16pt neutral400
// Caller name 36pt bold white Georgia
// Call type: emoji + "Chaperoned Call" 14pt neutral400
// ─────────────────────────────────────────────

class _CallerInfo extends StatelessWidget {
  const _CallerInfo({
    required this.callerName,
    required this.callType,
    required this.participantType,
  });

  final String   callerName;
  final CallType callType;
  final String   participantType;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          participantType == 'wali'
              ? 'Guardian call invite'
              : 'Incoming call',
          style: const TextStyle(
            fontSize: 16,
            color:    Color(0xFFAAAAAA), // neutral400
          ),
        ).animate().fadeIn(duration: 400.ms),

        const SizedBox(height: 10),

        Text(
          callerName,
          style: const TextStyle(
            fontFamily:  'Georgia',
            fontSize:    36,
            fontWeight:  FontWeight.w700,
            color:       AppColors.white,
          ),
        ).animate(delay: 100.ms)
         .fadeIn(duration: 400.ms)
         .slideY(begin: 0.1, end: 0, duration: 400.ms,
             curve: Curves.easeOutCubic),

        const SizedBox(height: 8),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(callType.emoji,
              style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text(callType.label,
              style: const TextStyle(
                fontSize: 14,
                color:    Color(0xFFAAAAAA), // neutral400
              ),
            ),
          ],
        ).animate(delay: 200.ms).fadeIn(duration: 400.ms),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// PULSE RINGS — concentric animated rings
// Ring 3 (220px): 8% opacity, 0.85→1.0 + fade 0.4→0.0, 1400ms
// Ring 2 (180px): 12% opacity, 0.90→1.0 + fade 0.6→0.15, 1200ms, 200ms delay
// Ring 1 (140px): 20% opacity, 0.95→1.0, 1000ms, 100ms delay
// Centre avatar (110px): roseGradient, shadow glow
// ─────────────────────────────────────────────

class _PulseRing extends StatelessWidget {
  const _PulseRing({required this.callerName});
  final String callerName;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220, height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ring 3 — outermost (220px)
          Container(
            width: 220, height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.roseDeep.withOpacity(0.08),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 0.85, end: 1.0, duration: 1400.ms)
              .fade(begin: 0.4, end: 0.0, duration: 1400.ms),

          // Ring 2 (180px)
          Container(
            width: 180, height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.roseDeep.withOpacity(0.12),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 0.90, end: 1.0,
                  duration: 1200.ms, delay: 200.ms)
              .fade(begin: 0.6, end: 0.15,
                  duration: 1200.ms, delay: 200.ms),

          // Ring 1 (140px)
          Container(
            width: 140, height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.roseDeep.withOpacity(0.20),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 0.95, end: 1.0,
                  duration: 1000.ms, delay: 100.ms),

          // Centre avatar (110px)
          Container(
            width: 110, height: 110,
            decoration: BoxDecoration(
              gradient: AppColors.roseGradient,
              shape:    BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color:      AppColors.roseDeep.withOpacity(0.40),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
                BoxShadow(
                  color:      AppColors.roseDeep.withOpacity(0.15),
                  blurRadius: 80,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Center(
              child: Text(
                callerName.isNotEmpty
                    ? callerName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontSize:   48,
                  color:      AppColors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CALL BUTTON — 72px circle with glow shadow
// Label below in neutral300 12pt
// slideY spring entrance at 500ms
// ─────────────────────────────────────────────

class _CallButton extends StatelessWidget {
  const _CallButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData     icon;
  final Color        color;
  final String       label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color:      color.withOpacity(0.40),
                  blurRadius: 20,
                  offset:     const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: AppColors.white, size: 32),
          ),
        ),
        const SizedBox(height: 10),
        Text(label,
          style: const TextStyle(
            fontSize: 12,
            color:    AppColors.neutral300,
          ),
        ),
      ],
    )
        .animate(delay: 500.ms)
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.25, end: 0,
            duration: 500.ms,
            curve: Curves.easeOutBack);
  }
}
