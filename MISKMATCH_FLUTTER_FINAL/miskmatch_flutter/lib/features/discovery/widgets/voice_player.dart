import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_typography.dart';

/// Inline voice intro player.
/// Shows a waveform-style animated bar + play/pause + duration.
///
/// Used in: Profile cards (discovery), Profile detail, Own profile preview.

class VoicePlayerWidget extends StatefulWidget {
  const VoicePlayerWidget({
    super.key,
    required this.audioUrl,
    this.label,
    this.maxDuration = 60,
  });

  final String audioUrl;
  final String? label;
  final int    maxDuration; // seconds

  @override
  State<VoicePlayerWidget> createState() => _VoicePlayerWidgetState();
}

class _VoicePlayerWidgetState extends State<VoicePlayerWidget>
    with SingleTickerProviderStateMixin {
  final _player = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;
  Duration    _position    = Duration.zero;
  Duration    _duration    = Duration.zero;
  bool        _loading     = false;

  late final AnimationController _waveCtrl;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _player.onPlayerStateChanged.listen((s) {
      if (mounted) {
        setState(() => _playerState = s);
        if (s == PlayerState.playing) {
          _waveCtrl.repeat(reverse: true);
        } else {
          _waveCtrl.stop();
        }
      }
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playerState = PlayerState.stopped;
          _position    = Duration.zero;
        });
        _waveCtrl.stop();
        _waveCtrl.reset();
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    _waveCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playerState == PlayerState.playing) {
      await _player.pause();
    } else {
      setState(() => _loading = true);
      try {
        await _player.play(UrlSource(widget.audioUrl));
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool get isPlaying => _playerState == PlayerState.playing;

  @override
  Widget build(BuildContext context) {
    final theme    = Theme.of(context);
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.roseDeep.withOpacity(0.06),
            AppColors.goldPrimary.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.roseDeep.withOpacity(0.12),
        ),
      ),
      child: Row(
        children: [
          // ── Play / Pause button ───────────────────────────────────────
          GestureDetector(
            onTap: _toggle,
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: AppColors.roseGradient,
                shape:    BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color:      AppColors.roseDeep.withOpacity(0.25),
                    blurRadius: 10,
                    offset:     const Offset(0, 3),
                  ),
                ],
              ),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          color: AppColors.white, strokeWidth: 2),
                    )
                  : Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: AppColors.white,
                      size: 26,
                    ),
            ),
          ),

          const SizedBox(width: 12),

          // ── Waveform + label + progress ────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Label
                if (widget.label != null)
                  Text(
                    widget.label!,
                    style: AppTypography.labelSmall.copyWith(
                      color:      AppColors.roseDeep,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                const SizedBox(height: 6),

                // Animated waveform bars
                _WaveformBars(
                  isPlaying:  isPlaying,
                  controller: _waveCtrl,
                  progress:   progress,
                ),

                const SizedBox(height: 6),

                // Duration
                Row(
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.roseDeep,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _duration.inSeconds > 0
                          ? _formatDuration(_duration)
                          : '0:${widget.maxDuration.toString().padLeft(2, '0')}',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.neutral500,
                      ),
                    ),
                  ],
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
// ANIMATED WAVEFORM BARS
// ─────────────────────────────────────────────

class _WaveformBars extends StatelessWidget {
  const _WaveformBars({
    required this.isPlaying,
    required this.controller,
    required this.progress,
  });

  final bool              isPlaying;
  final AnimationController controller;
  final double            progress;

  static const _barCount  = 28;
  static const _barHeights = [
    0.3, 0.7, 0.5, 0.9, 0.6, 0.4, 0.8, 0.5, 0.7, 0.3,
    0.9, 0.6, 0.4, 0.8, 0.5, 0.7, 0.3, 0.6, 0.9, 0.4,
    0.7, 0.5, 0.8, 0.3, 0.6, 0.9, 0.4, 0.7,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, __) {
          return Row(
            children: List.generate(_barCount, (i) {
              final isPast  = (i / _barCount) <= progress;
              final baseH   = _barHeights[i % _barHeights.length];
              final animH   = isPlaying && isPast
                  ? baseH * (0.6 + 0.4 * controller.value)
                  : baseH;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Align(
                    alignment: Alignment.center,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      height: 28 * animH,
                      decoration: BoxDecoration(
                        color: isPast
                            ? AppColors.roseDeep
                            : AppColors.roseDeep.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
