import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_typography.dart';

/// Inline voice intro player — 64px tall, rose gradient container.
/// 28-bar animated waveform with sine wave pattern.

class VoicePlayerWidget extends StatefulWidget {
  const VoicePlayerWidget({
    super.key,
    required this.audioUrl,
    this.label,
    this.maxDuration = 60,
  });

  final String  audioUrl;
  final String? label;
  final int     maxDuration;

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
    );

    _player.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      setState(() => _playerState = s);
      if (s == PlayerState.playing) {
        _waveCtrl.repeat(reverse: true);
      } else {
        _waveCtrl.stop();
      }
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _playerState = PlayerState.stopped;
        _position    = Duration.zero;
      });
      _waveCtrl.stop();
      _waveCtrl.reset();
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

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool get _isPlaying => _playerState == PlayerState.playing;

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.roseDeep.withOpacity(0.08),
            AppColors.goldPrimary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color:      AppColors.roseDeep.withOpacity(0.06),
            blurRadius: 8,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Play / Pause circle — 44px, rose gradient, gold glow ──
          GestureDetector(
            onTap: _toggle,
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: AppColors.roseGradient,
                shape:    BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color:      AppColors.goldPrimary.withOpacity(0.25),
                    blurRadius: 12,
                    offset:     const Offset(0, 2),
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
                      _isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: AppColors.white,
                      size: 26,
                    ),
            ),
          ),

          const SizedBox(width: 12),

          // ── 28-bar waveform ──────────────────────────────────────
          Expanded(
            child: _WaveformBars(
              isPlaying:  _isPlaying,
              controller: _waveCtrl,
              progress:   progress,
            ),
          ),

          const SizedBox(width: 12),

          // ── Timer MM:SS — 11pt roseDeep ──────────────────────────
          Text(
            _isPlaying || _position.inSeconds > 0
                ? _fmt(_position)
                : _duration.inSeconds > 0
                    ? _fmt(_duration)
                    : '0:${widget.maxDuration.toString().padLeft(2, '0')}',
            style: AppTypography.labelSmall.copyWith(
              color:    AppColors.roseDeep,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ANIMATED WAVEFORM BARS — sine wave pattern
// ─────────────────────────────────────────────

class _WaveformBars extends StatelessWidget {
  const _WaveformBars({
    required this.isPlaying,
    required this.controller,
    required this.progress,
  });

  final bool               isPlaying;
  final AnimationController controller;
  final double             progress;

  static const _barCount = 28;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, __) {
          return Row(
            children: List.generate(_barCount, (i) {
              final isPast = (i / _barCount) <= progress;
              // Sine wave pattern for natural waveform look
              final base = 0.3 + 0.7 * ((math.sin(i * 0.8) + 1) / 2);
              final animH = isPlaying && isPast
                  ? base * (0.6 + 0.4 * math.sin(
                      controller.value * math.pi + i * 0.4).abs())
                  : base * 0.6;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0.8),
                  child: Align(
                    alignment: Alignment.center,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 80),
                      height: 28 * animH.clamp(0.15, 1.0),
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
