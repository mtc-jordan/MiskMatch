import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../data/call_models.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/shared/extensions/app_extensions.dart';

/// A single call log tile — shown in the match screen call history section
/// and optionally in a dedicated calls list.

class CallHistoryTile extends StatelessWidget {
  const CallHistoryTile({
    super.key,
    required this.call,
    required this.otherName,
    required this.isInitiator,
    this.index = 0,
    this.onTap,
  });

  final CallModel    call;
  final String       otherName;
  final bool         isInitiator;
  final int          index;
  final VoidCallback? onTap;

  IconData get _icon => switch (call.status) {
    CallStatus.ended    => isInitiator
        ? Icons.call_made_rounded
        : Icons.call_received_rounded,
    CallStatus.missed   => Icons.call_missed_rounded,
    CallStatus.active   => Icons.call_rounded,
    CallStatus.ringing  => Icons.phone_in_talk_rounded,
    CallStatus.scheduled=> Icons.schedule_rounded,
  };

  Color get _iconColor => switch (call.status) {
    CallStatus.ended    => AppColors.success,
    CallStatus.missed   => AppColors.error,
    CallStatus.active   => AppColors.roseDeep,
    CallStatus.ringing  => AppColors.roseDeep,
    CallStatus.scheduled=> AppColors.goldPrimary,
  };

  String get _label => switch (call.status) {
    CallStatus.ended    => isInitiator ? 'Outgoing' : 'Incoming',
    CallStatus.missed   => 'Missed',
    CallStatus.active   => 'In progress',
    CallStatus.ringing  => 'Ringing',
    CallStatus.scheduled=> 'Scheduled',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(children: [
          // Icon
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color:  _iconColor.withOpacity(0.1),
              shape:  BoxShape.circle,
              border: Border.all(color: _iconColor.withOpacity(0.2)),
            ),
            child: Icon(_icon, color: _iconColor, size: 20),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(_label,
                      style: AppTypography.titleSmall.copyWith(
                        color: _iconColor)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color:        theme.colorScheme.outlineVariant
                          .withOpacity(0.2),
                      borderRadius: AppRadius.chipRadius,
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(call.callType.emoji,
                          style: const TextStyle(fontSize: 11)),
                      const SizedBox(width: 4),
                      Text(call.callType.label,
                          style: AppTypography.labelSmall.copyWith(
                            color:   theme.colorScheme.onSurfaceVariant,
                            fontSize:10,
                          )),
                    ]),
                  ),
                ]),
                const SizedBox(height: 2),
                Row(children: [
                  Text(otherName,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.neutral700)),
                  if (call.waliJoined) ...[
                    const SizedBox(width: 6),
                    const Text('🛡️', style: TextStyle(fontSize: 12)),
                  ],
                ]),
              ],
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                call.startedAt?.timeAgo ??
                call.scheduledAt?.shortDate ?? '',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.neutral500),
              ),
              const SizedBox(height: 3),
              Text(
                call.status == CallStatus.ended
                    ? call.formattedDuration
                    : call.status.name.capitalised,
                style: AppTypography.labelSmall.copyWith(
                  color: _iconColor, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ]),
      ),
    )
        .animate(delay: Duration(milliseconds: index * 40))
        .fadeIn(duration: 300.ms)
        .slideX(begin: 0.03, end: 0);
  }
}
