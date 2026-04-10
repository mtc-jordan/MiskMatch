import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:miskmatch/features/match/data/match_models.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/features/discovery/widgets/voice_player.dart';

/// Chat message bubble.
///
/// Mine (right): roseGradient, white text, bottom-right 4px corner
/// Theirs (left): white, neutral900 text, bottom-left 4px corner

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
    // Flagged messages — error tint
    if (message.isFlagged && isMe) return _FlaggedBubble(message: message);

    return Padding(
      padding: EdgeInsets.only(
        left:   isMe ? 64 : 16,
        right:  isMe ? 16 : 64,
        bottom: 4,
        top:    showTimestamp ? 16 : 2,
      ),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
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
                    color:    context.mutedText,
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
      context:         context,
      backgroundColor: Colors.transparent,
      builder:         (_) => _MessageMenu(
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
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        // Mine: roseGradient, Theirs: themed surface
        gradient: isMe && !message.isAudio
            ? AppColors.roseGradient
            : null,
        color: isMe
            ? (message.isAudio ? AppColors.roseDeep.withOpacity(0.06) : null)
            : context.subtleBg,
        borderRadius: BorderRadius.only(
          topLeft:     const Radius.circular(20),
          topRight:    const Radius.circular(20),
          bottomLeft:  Radius.circular(isMe ? 20 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 20),
        ),
        border: !isMe
            ? Border.all(
                color: context.cardBorder,
                width: 1,
              )
            : null,
        boxShadow: !isMe
            ? [
                BoxShadow(
                  color:      AppColors.roseDeep.withOpacity(0.04),
                  blurRadius: 6,
                  offset:     const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: message.isAudio && message.mediaUrl != null
          ? Padding(
              padding: const EdgeInsets.all(8),
              child: VoicePlayerWidget(
                audioUrl:    message.mediaUrl!,
                maxDuration: 60,
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              child: SelectableText(
                message.content,
                style: AppTypography.bodyMedium.copyWith(
                  color:  isMe ? AppColors.white : context.onSurface,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────
// READ TICK — gold flash on read
// ─────────────────────────────────────────────

class _ReadTick extends StatelessWidget {
  const _ReadTick({required this.status});
  final MessageStatus status;

  @override
  Widget build(BuildContext context) {
    final icon = switch (status) {
      MessageStatus.sent => const Icon(Icons.check,
          size: 14, color: AppColors.neutral500),
      MessageStatus.delivered => const Icon(Icons.done_all,
          size: 14, color: AppColors.neutral500),
      MessageStatus.read => const Icon(Icons.done_all,
          size: 14, color: AppColors.goldPrimary)
          .animate()
          .shimmer(duration: 600.ms, delay: 100.ms,
                   color: AppColors.goldLight.withOpacity(0.5)),
      MessageStatus.flagged => const Icon(Icons.flag_rounded,
          size: 14, color: AppColors.error),
    };
    return icon;
  }
}

// ─────────────────────────────────────────────
// FLAGGED BUBBLE — error tint
// ─────────────────────────────────────────────

class _FlaggedBubble extends StatelessWidget {
  const _FlaggedBubble({required this.message});
  final Message message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 64, right: 16, bottom: 4, top: 2),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color:        AppColors.errorLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppColors.error.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🚩', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Not delivered',
                  style: AppTypography.bodySmall.copyWith(
                    color:     AppColors.error,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
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
    return Container(
      decoration: BoxDecoration(
        color:        context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color:        context.handleColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ListTile(
            leading: Icon(Icons.copy_rounded,
                color: context.subtleText),
            title: const Text('Copy message'),
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
              leading:   const Icon(Icons.flag_outlined,
                  color: AppColors.error),
              title:     const Text('Report message'),
              textColor: AppColors.error,
              iconColor: AppColors.error,
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
