import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/call_models.dart';
import '../providers/call_provider.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/shared/extensions/app_extensions.dart';

/// Incoming call screen — shown to the receiver and the wali
/// when someone initiates a call.
///
/// Full-screen takeover with:
///   - Caller info (avatar, name, call type)
///   - Islamic reminder ("Both guardians will be present")
///   - Animated pulse ring
///   - Decline (red) + Accept (green) buttons

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
  final String   participantType;  // "receiver" | "wali"
  final String   myName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callState = ref.watch(callProvider);

    return Scaffold(
      backgroundColor: AppColors.midnightDeep,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),

            // ── Caller info ───────────────────────────────────────
            _CallerInfo(
              callerName: callerName,
              callType:   callType,
              participantType: participantType,
            ),

            const SizedBox(height: 20),

            // ── Animated ring ─────────────────────────────────────
            _PulseRing(callerName: callerName),

            const SizedBox(height: 40),

            // ── Wali presence note ─────────────────────────────────
            if (callType.isChaperoned)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color:        AppColors.goldPrimary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                        color: AppColors.goldPrimary.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Text('🛡️', style: TextStyle(fontSize: 18)),
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
                  ]),
                ).animate(delay: 300.ms).fadeIn(),
              ),

            const Spacer(),

            // ── Action buttons ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(48, 0, 48, 48),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Decline
                  _CallButton(
                    icon:  Icons.call_end_rounded,
                    color: AppColors.error,
                    label: 'Decline',
                    onTap: () {
                      Haptic.medium();
                      ref.read(callProvider.notifier).declineCall(callId);
                      Navigator.of(context).pop();
                    },
                  ),

                  // Accept
                  _CallButton(
                    icon:  callType.isVideo
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
                            'callId':   callId,
                            'callType': callType,
                            'myName':   myName,
                            'otherName':callerName,
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
    );
  }
}

// ─────────────────────────────────────────────
// CALLER INFO
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
    return Column(children: [
      Text(
        participantType == 'wali' ? 'Guardian call invite' : 'Incoming call',
        style: AppTypography.bodyMedium.copyWith(
          color: AppColors.neutral300),
      )
          .animate().fadeIn(duration: 400.ms),

      const SizedBox(height: 8),

      Text(callerName,
          style: AppTypography.headlineLarge.copyWith(
            color:      AppColors.white,
            fontWeight: FontWeight.w700,
          ))
          .animate(delay: 100.ms).fadeIn().slideY(begin: 0.1, end: 0),

      const SizedBox(height: 8),

      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(callType.emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 6),
        Text(callType.label,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.neutral400)),
      ]).animate(delay: 200.ms).fadeIn(),
    ]);
  }
}

// ─────────────────────────────────────────────
// PULSE RING  — animated concentric rings
// ─────────────────────────────────────────────

class _PulseRing extends StatelessWidget {
  const _PulseRing({required this.callerName});
  final String callerName;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220, height: 220,
      child: Stack(alignment: Alignment.center, children: [
        // Outer ring 3
        Container(
          width: 220, height: 220,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.roseDeep.withOpacity(0.08),
          ),
        ).animate(onPlay: (c) => c.repeat(reverse: true))
         .scaleXY(begin: 0.85, end: 1.0, duration: 1400.ms)
         .fade(begin: 0.4, end: 0.0, duration: 1400.ms),

        // Outer ring 2
        Container(
          width: 180, height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.roseDeep.withOpacity(0.12),
          ),
        ).animate(onPlay: (c) => c.repeat(reverse: true))
         .scaleXY(begin: 0.9, end: 1.0, duration: 1200.ms, delay: 200.ms)
         .fade(begin: 0.6, end: 0.15, duration: 1200.ms, delay: 200.ms),

        // Inner ring
        Container(
          width: 140, height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.roseDeep.withOpacity(0.2),
          ),
        ).animate(onPlay: (c) => c.repeat(reverse: true))
         .scaleXY(begin: 0.95, end: 1.0, duration: 1000.ms, delay: 100.ms),

        // Avatar
        Container(
          width:  110, height: 110,
          decoration: BoxDecoration(
            gradient: AppColors.roseGradient,
            shape:    BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color:      AppColors.roseDeep.withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Center(
            child: Text(
              callerName.isNotEmpty ? callerName[0].toUpperCase() : '?',
              style: AppTypography.displayMedium.copyWith(
                color:      AppColors.white,
                fontWeight: FontWeight.w700,
                fontSize:   48,
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// CALL BUTTON
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
    return Column(mainAxisSize: MainAxisSize.min, children: [
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: color, shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color:      color.withOpacity(0.4),
                blurRadius: 16,
                offset:     const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: AppColors.white, size: 32),
        ),
      ),
      const SizedBox(height: 8),
      Text(label,
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.neutral300)),
    ])
        .animate(delay: const Duration(milliseconds: 500))
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.2, end: 0, curve: Curves.easeOutBack);
  }
}

extension on AppColors {
  static const neutral400 = Color(0xFFAAAAAA);
}
