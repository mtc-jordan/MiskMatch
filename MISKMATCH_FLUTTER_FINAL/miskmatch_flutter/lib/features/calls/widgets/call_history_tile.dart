import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../data/call_models.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/shared/extensions/app_extensions.dart';

/// Call history tile — 72px standard list tile.
///
/// Left:  44px icon circle (outgoing/incoming/missed/active)
/// Centre: status label (coloured) + call type badge, name + wali shield
/// Right: time ago + duration bold coloured
/// Stagger: 40ms per index

class CallHistoryTile extends StatelessWidget {
  const CallHistoryTile({
    super.key,
    required this.call,
    required this.otherName,
    required this.isInitiator,
    this.index = 0,
    this.onTap,
  });

  final CallModel     call;
  final String        otherName;
  final bool          isInitiator;
  final int           index;
  final VoidCallback? onTap;

  // ── Icon per status ────────────────────────────
  IconData get _icon => switch (call.status) {
    CallStatus.ended     => isInitiator
        ? Icons.call_made_rounded        // up-right arrow
        : Icons.call_received_rounded,   // down-left arrow
    CallStatus.missed    => Icons.call_missed_rounded,
    CallStatus.active    => Icons.call_rounded,
    CallStatus.ringing   => Icons.phone_in_talk_rounded,
    CallStatus.scheduled => Icons.schedule_rounded,
  };

  // ── Colour per status ──────────────────────────
  Color get _color => switch (call.status) {
    CallStatus.ended     => isInitiator
        ? AppColors.success   // outgoing → green
        : AppColors.roseDeep, // incoming → rose
    CallStatus.missed    => AppColors.error,
    CallStatus.active    => AppColors.roseDeep,
    CallStatus.ringing   => AppColors.roseDeep,
    CallStatus.scheduled => AppColors.goldPrimary,
  };

  // ── Status label ───────────────────────────────
  String get _label => switch (call.status) {
    CallStatus.ended     => isInitiator ? 'Outgoing' : 'Incoming',
    CallStatus.missed    => 'Missed',
    CallStatus.active    => 'In progress',
    CallStatus.ringing   => 'Ringing',
    CallStatus.scheduled => 'Scheduled',
  };

  @override
  Widget build(BuildContext context) {
    final isActive = call.status == CallStatus.active;

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 72,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            // ── Left: 44px icon circle ───────────────
            _buildIconCircle(isActive),

            const SizedBox(width: 14),

            // ── Centre: status + name ────────────────
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status label + call type badge
                  Row(children: [
                    Text(_label,
                      style: AppTypography.titleSmall.copyWith(
                        color:      _color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Small call type badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color:        _color.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(call.callType.emoji,
                            style: const TextStyle(fontSize: 10)),
                          const SizedBox(width: 3),
                          Text(call.callType.label,
                            style: AppTypography.labelSmall.copyWith(
                              color:    _color.withOpacity(0.7),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]),

                  const SizedBox(height: 3),

                  // Name + wali shield
                  Row(children: [
                    Text(otherName,
                      style: AppTypography.bodySmall.copyWith(
                        color: context.subtleText),
                    ),
                    if (call.waliJoined) ...[
                      const SizedBox(width: 6),
                      const Text('🛡️',
                        style: TextStyle(fontSize: 12)),
                    ],
                  ]),
                ],
              ),
            ),

            // ── Right: time + duration ───────────────
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Time ago or date
                Text(
                  call.startedAt?.timeAgo ??
                  call.scheduledAt?.shortDate ?? '',
                  style: AppTypography.labelSmall.copyWith(
                    color: context.mutedText),
                ),
                const SizedBox(height: 3),
                // Duration (bold coloured) or status name
                Text(
                  call.status == CallStatus.ended
                      ? call.formattedDuration
                      : call.status.name.capitalised,
                  style: AppTypography.labelSmall.copyWith(
                    color:      _color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ]),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: index * 60))
        .fadeIn(duration: 350.ms)
        .slideY(begin: 0.05, end: 0, duration: 350.ms,
            curve: Curves.easeOutCubic);
  }

  Widget _buildIconCircle(bool isActive) {
    final circle = Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: _color.withOpacity(0.10),
        shape: BoxShape.circle,
      ),
      child: Icon(_icon, color: _color, size: 20),
    );

    if (isActive) {
      // Pulsing circle for active calls
      return circle
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(begin: 1.0, end: 1.08, duration: 800.ms)
          .fade(begin: 1.0, end: 0.7, duration: 800.ms);
    }

    return circle;
  }
}
