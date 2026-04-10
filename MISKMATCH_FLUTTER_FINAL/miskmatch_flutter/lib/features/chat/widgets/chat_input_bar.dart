import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:record/record.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';

// ═══════════════════════════════════════════════════════════
// TYPING INDICATOR — 3 animated bounce dots
// ═══════════════════════════════════════════════════════════

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key, required this.userName});
  final String userName;

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>>   _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) => AnimationController(
      vsync: this, duration: 600.ms,
    ));
    _animations = _controllers.map((c) => CurvedAnimation(
      parent: c, curve: Curves.easeInOut,
    )).toList();

    for (var i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 180), () {
        if (mounted) _controllers[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 6, top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color:        context.subtleBg,
              borderRadius: const BorderRadius.only(
                topLeft:     Radius.circular(20),
                topRight:    Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft:  Radius.circular(4),
              ),
              border: Border.all(
                color: context.cardBorder, width: 1),
            ),
            child: Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  AnimatedBuilder(
                    animation: _animations[i],
                    builder: (_, __) => Transform.translate(
                      offset: Offset(0, -4 * _animations[i].value),
                      child: Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(
                          color: context.mutedText,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  if (i < 2) const SizedBox(width: 4),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('${widget.userName} is typing...',
            style: AppTypography.bodySmall.copyWith(
              color:    context.mutedText,
              fontSize: 11,
            ),
          ),
        ],
      ),
    )
        .animate()
        .slideX(begin: -0.1, end: 0, duration: 300.ms,
                curve: Curves.easeOutCubic)
        .fadeIn(duration: 300.ms);
  }
}

// ═══════════════════════════════════════════════════════════
// CHAT INPUT BAR
// ═══════════════════════════════════════════════════════════

class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    required this.onSendText,
    required this.onSendVoice,
    required this.onTyping,
    this.disabled = false,
  });

  final void Function(String)  onSendText;
  final void Function(String)  onSendVoice;
  final void Function(String)  onTyping;
  final bool                   disabled;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _ctrl       = TextEditingController();
  final _focusNode  = FocusNode();
  bool  _hasText    = false;
  bool  _isRecording = false;
  int   _recSeconds = 0;
  Timer?  _recTimer;
  final _recorder = AudioRecorder();
  String? _recordingPath;
  double _swipeOffset = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    _recTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    setState(() => _hasText = text.trim().isNotEmpty);
    widget.onTyping(text);
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    widget.onSendText(text);
    _ctrl.clear();
    setState(() => _hasText = false);
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return;

    HapticFeedback.mediumImpact();
    final dir  = Directory.systemTemp;
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    _recordingPath = path;

    setState(() {
      _isRecording = true;
      _recSeconds  = 0;
      _swipeOffset = 0;
    });

    _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _recSeconds++);
      if (_recSeconds >= 60) _stopRecording();
    });
  }

  Future<void> _stopRecording() async {
    _recTimer?.cancel();
    await _recorder.stop();
    final path = _recordingPath;
    setState(() {
      _isRecording = false;
      _recSeconds  = 0;
    });
    if (path != null) {
      widget.onSendVoice(path);
    }
  }

  void _cancelRecording() async {
    _recTimer?.cancel();
    await _recorder.stop();
    HapticFeedback.lightImpact();
    setState(() {
      _isRecording = false;
      _recSeconds  = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    // ── Recording mode ──────────────────────────────────────
    if (_isRecording) {
      return GestureDetector(
        onHorizontalDragUpdate: (details) {
          setState(() {
            _swipeOffset += details.delta.dx;
            if (_swipeOffset < 0) _swipeOffset = 0;
          });
        },
        onHorizontalDragEnd: (details) {
          final width = MediaQuery.of(context).size.width;
          if (_swipeOffset > width * 0.4) {
            _cancelRecording();
          }
          setState(() => _swipeOffset = 0);
        },
        child: _RecordingBar(
          seconds:  _recSeconds,
          onStop:   _stopRecording,
          onCancel: _cancelRecording,
        ),
      );
    }

    // ── Normal input mode ───────────────────────────────────
    return Container(
      padding: EdgeInsets.only(
        left: 12, right: 12, top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 10 : 16,
      ),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        boxShadow: [
          BoxShadow(
            color:      AppColors.roseDeep.withOpacity(0.06),
            blurRadius: 16,
            offset:     const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Text field — rounded, multiline, max 5 rows
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color:        context.subtleBg.withOpacity(0.5),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: context.cardBorder.withOpacity(0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller:      _ctrl,
                      focusNode:       _focusNode,
                      enabled:         !widget.disabled,
                      maxLines:        5,
                      minLines:        1,
                      textDirection:   TextDirection.ltr,
                      onChanged:       _onChanged,
                      textInputAction: TextInputAction.newline,
                      style: AppTypography.bodyMedium.copyWith(
                        color: context.onSurface),
                      decoration: InputDecoration(
                        border:         InputBorder.none,
                        hintText:       widget.disabled
                            ? 'Chat available when match is active'
                            : 'Message...',
                        hintStyle: AppTypography.bodyMedium.copyWith(
                          color: context.mutedText),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 12),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Send / mic button
          AnimatedSwitcher(
            duration: 200.ms,
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: anim,
              child: child,
            ),
            child: _hasText
                ? _SendBtn(onTap: _send, key: const ValueKey('send'))
                : _MicBtn(
                    key:      const ValueKey('mic'),
                    onHold:   _startRecording,
                    disabled: widget.disabled,
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SEND BUTTON — rose circle 48px, spring scale
// ─────────────────────────────────────────────

class _SendBtn extends StatelessWidget {
  const _SendBtn({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          gradient: AppColors.roseGradient,
          shape:    BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color:      AppColors.roseDeep.withOpacity(0.25),
              blurRadius: 8,
              offset:     const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.send_rounded,
            color: AppColors.white, size: 22),
      ),
    ).animate().scale(
        begin: const Offset(0.6, 0.6),
        end:   const Offset(1.0, 1.0),
        duration: 200.ms,
        curve: Curves.easeOutBack);
  }
}

// ─────────────────────────────────────────────
// MIC BUTTON — rose tint circle, long-press
// ─────────────────────────────────────────────

class _MicBtn extends StatelessWidget {
  const _MicBtn({
    super.key,
    required this.onHold,
    required this.disabled,
  });
  final VoidCallback onHold;
  final bool         disabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: disabled ? null : (_) => onHold(),
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: disabled
              ? context.subtleBg
              : AppColors.roseLight,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.mic_rounded,
          color: disabled ? context.mutedText : AppColors.roseDeep,
          size:  24,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// RECORDING BAR — morphed input, swipe to cancel
// ─────────────────────────────────────────────

class _RecordingBar extends StatelessWidget {
  const _RecordingBar({
    required this.seconds,
    required this.onStop,
    required this.onCancel,
  });
  final int          seconds;
  final VoidCallback onStop;
  final VoidCallback onCancel;

  String get _timer {
    final m = (seconds ~/ 60).toString().padLeft(1, '0');
    final s = (seconds  % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        boxShadow: [
          BoxShadow(
            color:      AppColors.roseDeep.withOpacity(0.06),
            blurRadius: 16,
            offset:     const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Cancel (trash)
          GestureDetector(
            onTap: onCancel,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: context.subtleBg,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.delete_outline_rounded,
                  color: context.mutedText, size: 22),
            ),
          ),

          const SizedBox(width: 14),

          // Red dot pulse + timer
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 10, height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .fade(begin: 0.4, end: 1.0, duration: 600.ms),

                const SizedBox(width: 10),

                Text('Recording $_timer',
                  style: AppTypography.labelMedium.copyWith(
                    color:      AppColors.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const Spacer(),

                Text('← Swipe to cancel',
                  style: AppTypography.caption.copyWith(
                    color: context.mutedText,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 14),

          // Stop & send
          GestureDetector(
            onTap: onStop,
            child: Container(
              width: 48, height: 48,
              decoration: const BoxDecoration(
                gradient: AppColors.roseGradient,
                shape:    BoxShape.circle,
              ),
              child: const Icon(Icons.stop_rounded,
                  color: AppColors.white, size: 24),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms);
  }
}
