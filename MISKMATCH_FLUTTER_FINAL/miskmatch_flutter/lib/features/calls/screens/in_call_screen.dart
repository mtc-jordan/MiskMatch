import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/call_models.dart';
import '../providers/call_provider.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/shared/extensions/app_extensions.dart';

/// In-call screen — full-screen active call with
/// top gradient bar, video/audio areas, wali indicator,
/// 5-button control bar, and end-call confirmation sheet.

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
            // ── Main area (video or audio) ────────────────
            if (callType.isVideo)
              _VideoArea(
                callState: callState,
                myName:    myName,
                otherName: otherName,
              )
            else
              _AudioArea(
                callState: callState,
                myName:    myName,
                otherName: otherName,
              ),

            // ── Top bar — gradient overlay ────────────────
            Positioned(
              top: 0, left: 0, right: 0,
              child: _TopBar(
                callState: callState,
                callType:  callType,
                otherName: otherName,
              ),
            ),

            // ── Wali indicator ────────────────────────────
            if (callState.call?.waliInvited == true)
              Positioned(
                top: MediaQuery.of(context).padding.top + 60,
                right: 16,
                child: _WaliIndicator(
                  joined: callState.waliJoined,
                ),
              ),

            // ── Control bar — bottom gradient ─────────────
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _ControlBar(
                callState: callState,
                callType:  callType,
                onMic:     () {
                  Haptic.selection();
                  ref.read(callProvider.notifier).toggleAudio();
                },
                onVideo: () {
                  Haptic.selection();
                  ref.read(callProvider.notifier).toggleVideo();
                },
                onSpeaker: () {
                  Haptic.selection();
                  ref.read(callProvider.notifier).toggleSpeaker();
                },
                onFlip: () {
                  Haptic.selection();
                  ref.read(callProvider.notifier).flipCamera();
                },
                onEnd: () {
                  Haptic.heavy();
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
// Black→transparent gradient top 15%
// Call type badge (gold tint for chaperoned, rose for other)
// Live timer with red dot pulse 800ms
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
        left:   16, right: 16, bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end:   Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.65),
            Colors.black.withOpacity(0.25),
            Colors.transparent,
          ],
          stops: const [0.0, 0.7, 1.0],
        ),
      ),
      child: Row(children: [
        // ── Call type badge ───────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: callType.isChaperoned
                ? AppColors.goldPrimary.withOpacity(0.20)
                : AppColors.roseDeep.withOpacity(0.20),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: callType.isChaperoned
                  ? AppColors.goldPrimary.withOpacity(0.50)
                  : AppColors.roseDeep.withOpacity(0.40),
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(callType.emoji,
              style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 5),
            Text(callType.label,
              style: AppTypography.labelSmall.copyWith(
                color:      AppColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ]),
        ),

        const Spacer(),

        // ── Live timer ───────────────────────────
        if (callState.isActive)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color:        Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              // Red dot pulse
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .fade(begin: 1.0, end: 0.3, duration: 800.ms),
              const SizedBox(width: 6),
              Text(callState.elapsedFormatted,
                style: AppTypography.labelMedium.copyWith(
                  color:      AppColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ]),
          ),
      ]),
    ).animate().fadeIn(duration: 400.ms);
  }
}

// ─────────────────────────────────────────────
// VIDEO AREA
// Remote video: full screen placeholder
// Local preview: 100×140 bottom-left, 14px radius,
//   2px white border, elevated shadow
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
      _VideoPlaceholder(
        name:     otherName,
        isRemote: true,
        isMuted:  false,
      ),

      // Local preview — bottom left, above control bar
      Positioned(
        bottom: 160, left: 16,
        child: Container(
          width: 100, height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.white.withOpacity(0.8),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withOpacity(0.3),
                blurRadius: 12,
                offset:     const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
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
// AUDIO AREA
// midnightDeep bg, centered layout:
// 120px roseGradient avatar with slow pulse glow 1500ms
// 28pt white bold name (Georgia)
// Status text: elapsed / Ringing... / Connecting...
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
            // ── 120px avatar with pulse glow ─────────
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                gradient: AppColors.roseGradient,
                shape:    BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color:        AppColors.roseDeep.withOpacity(0.40),
                    blurRadius:   32,
                    spreadRadius: 4,
                  ),
                  BoxShadow(
                    color:        AppColors.roseDeep.withOpacity(0.15),
                    blurRadius:   64,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  otherName.isNotEmpty
                      ? otherName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontFamily:  'Georgia',
                    fontSize:    52,
                    color:       AppColors.white,
                    fontWeight:  FontWeight.w700,
                  ),
                ),
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 1.0, end: 1.04, duration: 1500.ms),

            const SizedBox(height: 24),

            // ── Name ─────────────────────────────────
            Text(otherName,
              style: const TextStyle(
                fontFamily:  'Georgia',
                fontSize:    28,
                color:       AppColors.white,
                fontWeight:  FontWeight.w700,
              ),
            ).animate().fadeIn(duration: 400.ms),

            const SizedBox(height: 8),

            // ── Status text ──────────────────────────
            Text(
              callState.isActive
                  ? callState.elapsedFormatted
                  : callState.isRinging
                      ? 'Ringing...'
                      : 'Connecting...',
              style: AppTypography.bodyMedium.copyWith(
                color: const Color(0xFFAAAAAA)),
            ),

            const SizedBox(height: 40),

            // ── You indicator ────────────────────────
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.person_rounded,
                color: Color(0xFFAAAAAA), size: 18),
              const SizedBox(width: 6),
              Text('You — $myName',
                style: AppTypography.bodySmall.copyWith(
                  color: const Color(0xFFAAAAAA)),
              ),
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
// VIDEO PLACEHOLDER
// Replaced by AgoraVideoView in production
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
                color: const Color(0xFFAAAAAA)),
            ),
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
// Joined: green 20% bg, green 50% border,
//   green dot pulse 800ms, "Guardian present"
// Invited: gold tint, static dot, "Guardian invited"
// Slides in from right 400ms
// ─────────────────────────────────────────────

class _WaliIndicator extends StatelessWidget {
  const _WaliIndicator({required this.joined});
  final bool joined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: joined
            ? AppColors.success.withOpacity(0.20)
            : AppColors.goldPrimary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: joined
              ? AppColors.success.withOpacity(0.50)
              : AppColors.goldPrimary.withOpacity(0.40),
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Text('🛡️', style: TextStyle(fontSize: 13)),
        const SizedBox(width: 5),
        Text(
          joined ? 'Guardian present' : 'Guardian invited',
          style: AppTypography.labelSmall.copyWith(
            color: joined
                ? AppColors.success
                : AppColors.goldPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 5),
        Container(
          width: 7, height: 7,
          decoration: BoxDecoration(
            color: joined
                ? AppColors.success
                : AppColors.goldPrimary,
            shape: BoxShape.circle,
          ),
        ).animate(
          onPlay: (c) => joined ? c.repeat(reverse: true) : null,
        ).fade(duration: 800.ms),
      ]),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideX(begin: 0.15, end: 0, duration: 400.ms,
            curve: Curves.easeOutCubic);
  }
}

// ─────────────────────────────────────────────
// CONTROL BAR
// Transparent→black gradient bottom 25%
// 5 buttons: mic, camera, speaker, flip, end call
// Mic/Camera: active → white 15% 56px; muted → error 20% + error glow
// End call: 72px error circle with error glow
// All labels 11pt neutral300
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
        left:   24, right: 24, top: 24,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end:   Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.85),
            Colors.black.withOpacity(0.40),
            Colors.transparent,
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // ── Mic ────────────────────────
          _ControlBtn(
            icon:   callState.myAudioMuted
                ? Icons.mic_off_rounded
                : Icons.mic_rounded,
            label:  callState.myAudioMuted ? 'Unmute' : 'Mute',
            active: !callState.myAudioMuted,
            onTap:  onMic,
            danger: callState.myAudioMuted,
          ),

          // ── Camera (video only) ────────
          if (callType.isVideo)
            _ControlBtn(
              icon:   callState.myVideoMuted
                  ? Icons.videocam_off_rounded
                  : Icons.videocam_rounded,
              label:  callState.myVideoMuted ? 'Start cam' : 'Stop cam',
              active: !callState.myVideoMuted,
              onTap:  onVideo,
              danger: callState.myVideoMuted,
            ),

          // ── Speaker ────────────────────
          _ControlBtn(
            icon:   callState.speakerOn
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded,
            label:  callState.speakerOn ? 'Speaker' : 'Earpiece',
            active: callState.speakerOn,
            onTap:  onSpeaker,
          ),

          // ── Flip camera (video only) ───
          if (callType.isVideo)
            _ControlBtn(
              icon:   Icons.flip_camera_ios_rounded,
              label:  'Flip',
              active: true,
              onTap:  onFlip,
            ),

          // ── End call (72px) ────────────
          _ControlBtn(
            icon:  Icons.call_end_rounded,
            label: 'End',
            active: true,
            onTap:  onEnd,
            isEnd:  true,
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms);
  }
}

// ─────────────────────────────────────────────
// CONTROL BUTTON
// Normal: 56px white 15% circle
// Muted/danger: 56px error 20% + error glow shadow
// End: 72px error solid + error glow
// Label: 11pt neutral300
// ─────────────────────────────────────────────

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

  double get _size => isEnd ? 72.0 : 56.0;

  Color get _bg {
    if (isEnd)  return AppColors.error;
    if (danger) return AppColors.error.withOpacity(0.20);
    return Colors.white.withOpacity(0.15);
  }

  Color get _iconColor {
    if (isEnd)  return AppColors.white;
    if (danger) return AppColors.error;
    return AppColors.white;
  }

  List<BoxShadow> get _shadows {
    if (isEnd) {
      return [
        BoxShadow(
          color:      AppColors.error.withOpacity(0.45),
          blurRadius: 16,
          offset:     const Offset(0, 4),
        ),
      ];
    }
    if (danger) {
      return [
        BoxShadow(
          color:      AppColors.error.withOpacity(0.30),
          blurRadius: 12,
          offset:     const Offset(0, 2),
        ),
      ];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: _size, height: _size,
          decoration: BoxDecoration(
            color:    _bg,
            shape:    BoxShape.circle,
            boxShadow: _shadows,
          ),
          child: Icon(icon,
            color: _iconColor,
            size:  isEnd ? 32 : 26,
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
          style: const TextStyle(
            fontSize: 11,
            color:    AppColors.neutral300,
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// END CALL SHEET
// midnightSurface bg, handle bar
// "End this call?" 24pt Georgia white
// "All participants will be disconnected" muted
// "Stay in call" outline | "End call" error filled
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
        // Handle
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 20),
          width:  40, height: 4,
          decoration: BoxDecoration(
            color:        AppColors.neutral500.withOpacity(0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Title
        const Text('End this call?',
          style: TextStyle(
            fontFamily:  'Georgia',
            fontSize:    24,
            color:       AppColors.white,
            fontWeight:  FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),

        Text(
          'All participants will be disconnected.',
          style: AppTypography.bodyMedium.copyWith(
            color: const Color(0xFFAAAAAA)),
        ),
        const SizedBox(height: 28),

        // Action buttons
        Row(children: [
          // Stay in call — outline
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.white,
                side: const BorderSide(color: AppColors.neutral500),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Stay in call'),
            ),
          ),
          const SizedBox(width: 12),
          // End call — error filled
          Expanded(
            child: ElevatedButton(
              onPressed: onEnd,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('End call'),
            ),
          ),
        ]),
      ]),
    );
  }
}
