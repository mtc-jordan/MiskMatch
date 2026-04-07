import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:miskmatch/features/match/data/match_models.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/features/discovery/widgets/voice_player.dart';

/// A single chat message bubble.
///
/// Mine (right-aligned): Deep rose gradient, white text
/// Theirs (left-aligned): White surface, neutral text
///
/// Features:
///   - Read receipt ticks (sent / delivered / read)
///   - Voice message with inline player
///   - Flagged message notice
///   - Long-press context menu (copy, report)
///   - Animated entrance

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.showTimestamp = false,
    this.onReport,
    this.index = 0,
  });

  final Message       message;
  final bool          isMe;
  final bool          showTimestamp;
  final VoidCallback? onReport;
  final int           index;

  @override
  Widget build(BuildContext context) {
    if (message.isFlagged && isMe) return _FlaggedBubble(message: message);

    return Padding(
      padding: EdgeInsets.only(
        left:   isMe ? 64 : AppSpacing.screenPadding,
        right:  isMe ? AppSpacing.screenPadding : 64,
        bottom: 4,
        top:    showTimestamp ? 16 : 2,
      ),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Timestamp separator
          if (showTimestamp)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Center(
                child: _TimestampChip(time: message.createdAt),
              ),
            ),

          // Bubble
          GestureDetector(
            onLongPress: () => _showContextMenu(context),
            child: _BubbleContent(
              message: message,
              isMe:    isMe,
            ),
          )
              .animate(delay: Duration(milliseconds: index % 3 * 30))
              .fadeIn(duration: 250.ms)
              .slideX(
                begin: isMe ? 0.05 : -0.05,
                end:   0,
                duration: 250.ms,
                curve: Curves.easeOutCubic,
              ),

          const SizedBox(height: 2),

          // Time + read receipt
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.createdAt),
                  style: AppTypography.labelSmall.copyWith(
                    fontSize: 10,
                    color: AppColors.neutral500,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  _ReadTick(status: message.status),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context:          context,
      backgroundColor:  Colors.transparent,
      builder:          (_) => _MessageMenu(
        message:  message,
        isMe:     isMe,
        onReport: onReport,
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ─────────────────────────────────────────────
// BUBBLE CONTENT
// ─────────────────────────────────────────────

class _BubbleContent extends StatelessWidget {
  const _BubbleContent({required this.message, required this.isMe});
  final Message message;
  final bool    isMe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final bgColor = isMe
        ? theme.colorScheme.primary
        : theme.colorScheme.surface;

    final textColor = isMe
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;

    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        color:        message.isAudio ? Colors.transparent : bgColor,
        gradient:     isMe && !message.isAudio
            ? const LinearGradient(
                begin:  Alignment.topLeft,
                end:    Alignment.bottomRight,
                colors: [AppColors.roseDeep, AppColors.roseBlush],
              )
            : null,
        borderRadius: BorderRadius.only(
          topLeft:     const Radius.circular(AppRadius.lg),
          topRight:    const Radius.circular(AppRadius.lg),
          bottomLeft:  Radius.circular(isMe ? AppRadius.lg : 4),
          bottomRight: Radius.circular(isMe ? 4 : AppRadius.lg),
        ),
        boxShadow: [
          BoxShadow(
            color:      (isMe ? AppColors.roseDeep : AppColors.neutral900)
                .withOpacity(0.08),
            blurRadius: 8,
            offset:     const Offset(0, 2),
          ),
        ],
        border: !isMe
            ? Border.all(
                color: AppColors.neutral300.withOpacity(0.5),
                width: 1,
              )
            : null,
      ),
      child: message.isAudio && message.mediaUrl != null
          ? _AudioBubble(
              audioUrl:  message.mediaUrl!,
              isMe:      isMe,
              textColor: textColor,
            )
          : Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              child: SelectableText(
                message.content,
                style: AppTypography.bodyMedium.copyWith(
                  color:  textColor,
                  height: 1.45,
                ),
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────
// AUDIO BUBBLE
// ─────────────────────────────────────────────

class _AudioBubble extends StatelessWidget {
  const _AudioBubble({
    required this.audioUrl,
    required this.isMe,
    required this.textColor,
  });
  final String audioUrl;
  final bool   isMe;
  final Color  textColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: VoicePlayerWidget(
        audioUrl: audioUrl,
        label:    isMe ? 'Voice message' : 'Voice message',
        maxDuration: 60,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// READ TICK
// ─────────────────────────────────────────────

class _ReadTick extends StatelessWidget {
  const _ReadTick({required this.status});
  final MessageStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      MessageStatus.sent      => const Icon(Icons.check,
          size: 12, color: AppColors.neutral500),
      MessageStatus.delivered => const Icon(Icons.done_all,
          size: 12, color: AppColors.neutral500),
      MessageStatus.read      => const Icon(Icons.done_all,
          size: 12, color: AppColors.goldPrimary),
      MessageStatus.flagged   => const Icon(Icons.flag_rounded,
          size: 12, color: AppColors.error),
    };
  }
}

// ─────────────────────────────────────────────
// FLAGGED BUBBLE
// ─────────────────────────────────────────────

class _FlaggedBubble extends StatelessWidget {
  const _FlaggedBubble({required this.message});
  final Message message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left:   64,
        right:  AppSpacing.screenPadding,
        bottom: 4,
        top:    2,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color:        AppColors.errorLight,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.error.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.flag_rounded, color: AppColors.error, size: 14),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Message not delivered — content guidelines.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TIMESTAMP CHIP
// ─────────────────────────────────────────────

class _TimestampChip extends StatelessWidget {
  const _TimestampChip({required this.time});
  final DateTime time;

  String get _label {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay= DateTime(time.year, time.month, time.day);

    if (msgDay == today) return 'Today';
    if (msgDay == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${time.day}/${time.month}/${time.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color:        AppColors.neutral100,
        borderRadius: AppRadius.chipRadius,
      ),
      child: Text(
        _label,
        style: AppTypography.labelSmall.copyWith(
          color: AppColors.neutral500),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CONTEXT MENU
// ─────────────────────────────────────────────

class _MessageMenu extends StatelessWidget {
  const _MessageMenu({
    required this.message,
    required this.isMe,
    this.onReport,
  });
  final Message       message;
  final bool          isMe;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color:        theme.colorScheme.surface,
        borderRadius: AppRadius.bottomSheet,
      ),
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin:  const EdgeInsets.only(bottom: 8),
            width:   40, height: 4,
            decoration: BoxDecoration(
              color:        theme.colorScheme.outline.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ListTile(
            leading:  const Icon(Icons.copy_rounded),
            title:    const Text('Copy message'),
            onTap: () {
              Clipboard.setData(ClipboardData(text: message.content));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Message copied')),
              );
            },
          ),
          if (!isMe)
            ListTile(
              leading:    const Icon(Icons.flag_outlined,
                  color: AppColors.error),
              title:      const Text('Report message'),
              textColor:  AppColors.error,
              iconColor:  AppColors.error,
              onTap: () {
                Navigator.pop(context);
                onReport?.call();
              },
            ),
        ],
      ),
    );
  }
}
