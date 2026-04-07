import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/call_models.dart';
import '../providers/call_provider.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/shared/extensions/app_extensions.dart';

/// In-call screen — active 3-way chaperoned call.
///
/// Layout (video call):
///   ┌─────────────────────────────────┐
///   │  wali tile (top-right, small)   │ ← subscriber, observer
///   │                                 │
///   │  remote video (full screen)     │ ← the other party
///   │                                 │
///   │  [local preview — bottom-left]  │ ← self view (small)
///   └─────────────────────────────────┘
///   [mic] [cam] [speaker] [flip] [end]    ← control bar
///
/// For audio-only: solid dark background with avatars.
/// The wali tile is always visible with an indicator of their presence.

class InCallScreen extends ConsumerWidget {
  const InCallScreen({
    super.key,
    required this.callType,
    required this.myName,
    required this.otherName,
    required this.matchId,
  });

  final CallType callType;
  final String   myName;
  final String   otherName;
  final String   matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callState = ref.watch(callProvider);

    // Auto-pop when call ends
    ref.listen(callProvider, (prev, next) {
      if (next.phase == CallPhase.ended || next.phase == CallPhase.idle) {
        if (context.mounted) Navigator.of(context).pop();
      }
    });

    return WillPopScope(
      onWillPop: () async {
        _showEndCallSheet(context, ref);
        return false;
      },
      child: Scaffold(
        backgroundColor: AppColors.midnightDeep,
        body: Stack(
          children: [
            // ── Video area ─────────────────────────────────────────
            if (callType.isVideo)
              _VideoArea(
                callState:  callState,
                myName:     myName,
                otherName:  otherName,
              )
            else
              _AudioArea(
                callState:  callState,
                myName:     myName,
                otherName:  otherName,
              ),

            // ── Top bar ────────────────────────────────────────────
            Positioned(
              top: 0, left: 0, right: 0,
              child: _TopBar(
                callState: callState,
                callType:  callType,
                otherName: otherName,
              ),
            ),

            // ── Wali indicator ─────────────────────────────────────
            if (callState.call?.waliInvited == true)
              Positioned(
                top: 100, right: 16,
                child: _WaliIndicator(
                  joined: callState.waliJoined,
                ),
              ),

            // ── Control bar ────────────────────────────────────────
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _ControlBar(
                callState: callState,
                callType:  callType,
                onMic:     () {
                  Haptic.selection();
                  ref.read(callProvider.notifier).toggleAudio();
                },
                onVideo:   () {
                  Haptic.selection();
                  ref.read(callProvider.notifier).toggleVideo();
                },
                onSpeaker: () {
                  Haptic.selection();
                  ref.read(callProvider.notifier).toggleSpeaker();
                },
                onFlip:    () {
                  Haptic.selection();
                  ref.read(callProvider.notifier).flipCamera();
                },
                onEnd:     () {
                  Haptic.medium();
                  _showEndCallSheet(context, ref);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEndCallSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context:         context,
      backgroundColor: Colors.transparent,
      builder: (_) => _EndCallSheet(
        onEnd: () async {
          Navigator.of(context).pop(); // dismiss sheet
          await ref.read(callProvider.notifier).endCall();
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TOP BAR
// ─────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.callState,
    required this.callType,
    required this.otherName,
  });
  final CallState callState;
  final CallType  callType;
  final String    otherName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top:    MediaQuery.of(context).padding.top + 12,
        left:   16, right: 16, bottom: 12,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end:   Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.6),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(children: [
        // Call type badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color:        callType.isChaperoned
                ? AppColors.goldPrimary.withOpacity(0.2)
                : AppColors.roseDeep.withOpacity(0.2),
            borderRadius: AppRadius.chipRadius,
            border: Border.all(
              color: callType.isChaperoned
                  ? AppColors.goldPrimary.withOpacity(0.5)
                  : AppColors.roseDeep.withOpacity(0.4),
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(callType.emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 5),
            Text(callType.label,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.white, fontWeight: FontWeight.w600)),
          ]),
        ),

        const Spacer(),

        // Elapsed time
        if (callState.isActive)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color:        Colors.black.withOpacity(0.3),
              borderRadius: AppRadius.chipRadius,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.error, shape: BoxShape.circle),
              ).animate(onPlay: (c) => c.repeat(reverse: true))
               .fade(duration: 800.ms),
              const SizedBox(width: 6),
              Text(callState.elapsedFormatted,
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.white, fontWeight: FontWeight.w600)),
            ]),
          ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// VIDEO AREA
// ─────────────────────────────────────────────

class _VideoArea extends StatelessWidget {
  const _VideoArea({
    required this.callState,
    required this.myName,
    required this.otherName,
  });
  final CallState callState;
  final String    myName;
  final String    otherName;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      // Remote video — full screen
      // In production: AgoraVideoView for remote uid
      _VideoPlaceholder(
        name:       otherName,
        isRemote:   true,
        isMuted:    false,
      ),

      // Local preview — bottom left
      Positioned(
        bottom: 160, left: 16,
        child: Container(
          width: 100, height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.white.withOpacity(0.3)),
            boxShadow: AppShadows.elevated,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: _VideoPlaceholder(
              name:     myName,
              isRemote: false,
              isMuted:  callState.myVideoMuted,
              isSmall:  true,
            ),
          ),
        ).animate().fadeIn(duration: 400.ms),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────
// AUDIO AREA (no video)
// ─────────────────────────────────────────────

class _AudioArea extends StatelessWidget {
  const _AudioArea({
    required this.callState,
    required this.myName,
    required this.otherName,
  });
  final CallState callState;
  final String    myName;
  final String    otherName;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.midnightDeep,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Remote avatar
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                gradient: AppColors.roseGradient,
                shape:    BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color:      AppColors.roseDeep.withOpacity(0.4),
                    blurRadius: 32,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
                  style: AppTypography.displayMedium.copyWith(
                    color:      AppColors.white,
                    fontWeight: FontWeight.w700,
                    fontSize:   52,
                  ),
                ),
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 1.0, end: 1.04, duration: 1500.ms),

            const SizedBox(height: 24),

            Text(otherName,
                style: AppTypography.headlineMedium.copyWith(
                  color: AppColors.white, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              callState.isActive
                  ? callState.elapsedFormatted
                  : callState.isRinging ? 'Ringing...' : 'Connecting...',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.neutral400),
            ),

            const SizedBox(height: 40),

            // My avatar (small)
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.person_rounded,
                  color: AppColors.neutral400, size: 18),
              const SizedBox(width: 6),
              Text('You — $myName',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.neutral400)),
              if (callState.myAudioMuted) ...[
                const SizedBox(width: 8),
                const Icon(Icons.mic_off_rounded,
                    color: AppColors.error, size: 16),
              ],
            ]),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// VIDEO PLACEHOLDER  (replaced by AgoraVideoView in production)
// ─────────────────────────────────────────────

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder({
    required this.name,
    required this.isRemote,
    required this.isMuted,
    this.isSmall = false,
  });
  final String name;
  final bool   isRemote;
  final bool   isMuted;
  final bool   isSmall;

  @override
  Widget build(BuildContext context) {
    // Production: return AgoraVideoView(controller: VideoViewController(...))
    return Container(
      color: isRemote
          ? const Color(0xFF1A0A2E)
          : const Color(0xFF2A1245),
      child: Stack(alignment: Alignment.center, children: [
        Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircleAvatar(
            radius: isSmall ? 24 : 48,
            backgroundColor: AppColors.roseDeep.withOpacity(0.3),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize:   isSmall ? 20 : 40,
                color:      AppColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (!isSmall) ...[
            const SizedBox(height: 12),
            Text(isMuted ? '(Camera off)' : name,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.neutral400)),
          ],
        ]),

        // Muted icon overlay
        if (isMuted)
          Positioned(
            top: 8, right: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.videocam_off_rounded,
                  color: AppColors.error, size: 14),
            ),
          ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// WALI INDICATOR
// ─────────────────────────────────────────────

class _WaliIndicator extends StatelessWidget {
  const _WaliIndicator({required this.joined});
  final bool joined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color:        joined
            ? AppColors.success.withOpacity(0.2)
            : AppColors.neutral900.withOpacity(0.6),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: joined
              ? AppColors.success.withOpacity(0.5)
              : AppColors.neutral500.withOpacity(0.3),
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('🛡️', style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 5),
        Text(
          joined ? 'Guardian present' : 'Guardian invited',
          style: AppTypography.labelSmall.copyWith(
            color:      joined ? AppColors.success : AppColors.neutral400,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 5),
        Container(
          width: 7, height: 7,
          decoration: BoxDecoration(
            color: joined ? AppColors.success : AppColors.neutral500,
            shape: BoxShape.circle,
          ),
        ).animate(onPlay: (c) => joined ? c.repeat(reverse: true) : null)
         .fade(duration: 800.ms),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// CONTROL BAR
// ─────────────────────────────────────────────

class _ControlBar extends StatelessWidget {
  const _ControlBar({
    required this.callState,
    required this.callType,
    required this.onMic,
    required this.onVideo,
    required this.onSpeaker,
    required this.onFlip,
    required this.onEnd,
  });
  final CallState    callState;
  final CallType     callType;
  final VoidCallback onMic;
  final VoidCallback onVideo;
  final VoidCallback onSpeaker;
  final VoidCallback onFlip;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left:   24, right: 24, top: 20,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end:   Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mic
          _ControlBtn(
            icon:    callState.myAudioMuted
                ? Icons.mic_off_rounded : Icons.mic_rounded,
            label:   callState.myAudioMuted ? 'Unmute' : 'Mute',
            active:  !callState.myAudioMuted,
            onTap:   onMic,
            danger:  callState.myAudioMuted,
          ),

          // Camera (video only)
          if (callType.isVideo)
            _ControlBtn(
              icon:   callState.myVideoMuted
                  ? Icons.videocam_off_rounded : Icons.videocam_rounded,
              label:  callState.myVideoMuted ? 'Start cam' : 'Stop cam',
              active: !callState.myVideoMuted,
              onTap:  onVideo,
              danger: callState.myVideoMuted,
            ),

          // Speaker
          _ControlBtn(
            icon:   callState.speakerOn
                ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            label:  callState.speakerOn ? 'Speaker' : 'Earpiece',
            active: callState.speakerOn,
            onTap:  onSpeaker,
          ),

          // Flip camera (video only)
          if (callType.isVideo)
            _ControlBtn(
              icon:   Icons.flip_camera_ios_rounded,
              label:  'Flip',
              active: true,
              onTap:  onFlip,
            ),

          // End call
          _ControlBtn(
            icon:   Icons.call_end_rounded,
            label:  'End',
            active: true,
            onTap:  onEnd,
            isEnd:  true,
          ),
        ],
      ),
    );
  }
}

class _ControlBtn extends StatelessWidget {
  const _ControlBtn({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.danger = false,
    this.isEnd  = false,
  });
  final IconData     icon;
  final String       label;
  final bool         active;
  final VoidCallback onTap;
  final bool         danger;
  final bool         isEnd;

  Color get _bg {
    if (isEnd)    return AppColors.error;
    if (danger)   return AppColors.error.withOpacity(0.2);
    if (active)   return Colors.white.withOpacity(0.15);
    return Colors.white.withOpacity(0.08);
  }

  Color get _iconColor {
    if (isEnd)  return AppColors.white;
    if (danger) return AppColors.error;
    return active ? AppColors.white : AppColors.neutral500;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color:  _bg,
            shape:  BoxShape.circle,
            boxShadow: isEnd ? [
              BoxShadow(
                color:      AppColors.error.withOpacity(0.4),
                blurRadius: 12,
                offset:     const Offset(0, 3),
              ),
            ] : [],
          ),
          child: Icon(icon, color: _iconColor, size: 26),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.neutral300, fontSize: 11)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// END CALL SHEET
// ─────────────────────────────────────────────

class _EndCallSheet extends StatelessWidget {
  const _EndCallSheet({required this.onEnd});
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color:        AppColors.midnightSurface,
        borderRadius: AppRadius.bottomSheet,
      ),
      padding: EdgeInsets.only(
        left:   24, right: 24, top: 0,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          margin:  const EdgeInsets.only(top: 12, bottom: 20),
          width:   40, height: 4,
          decoration: BoxDecoration(
            color:        AppColors.neutral500.withOpacity(0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Text('End this call?',
            style: AppTypography.headlineSmall.copyWith(
              color: AppColors.white)),
        const SizedBox(height: 8),
        Text(
          'All participants will be disconnected.',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.neutral400),
        ),
        const SizedBox(height: 28),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.white,
                side: const BorderSide(color: AppColors.neutral500),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.buttonRadius),
              ),
              child: const Text('Stay in call'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: onEnd,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.buttonRadius),
              ),
              child: const Text('End call'),
            ),
          ),
        ]),
      ]),
    );
  }
}

extension on AppColors {
  static const neutral400 = Color(0xFFAAAAAA);
}
