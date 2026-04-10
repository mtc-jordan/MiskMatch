import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/call_models.dart';
import '../providers/call_provider.dart';
import '../screens/in_call_screen.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/shared/extensions/app_extensions.dart';
import 'package:miskmatch/shared/widgets/common_widgets.dart';

/// Bottom sheet — start or schedule a chaperoned call.
/// Header: 48px rose circle + "Call [Name]" + subtitle
/// Islamic note card, 3 toggle rows, date picker, CTA

Future<void> showCallScheduleSheet({
  required BuildContext context,
  required WidgetRef    ref,
  required String       matchId,
  required String       myName,
  required String       otherName,
}) async {
  await showModalBottomSheet(
    context:            context,
    isScrollControlled: true,
    backgroundColor:    Colors.transparent,
    builder: (_) => ProviderScope(
      parent: ProviderScope.containerOf(context),
      child:  _CallScheduleSheet(
        matchId:   matchId,
        myName:    myName,
        otherName: otherName,
      ),
    ),
  );
}

class _CallScheduleSheet extends ConsumerStatefulWidget {
  const _CallScheduleSheet({
    required this.matchId,
    required this.myName,
    required this.otherName,
  });
  final String matchId;
  final String myName;
  final String otherName;

  @override
  ConsumerState<_CallScheduleSheet> createState() =>
      _CallScheduleSheetState();
}

class _CallScheduleSheetState extends ConsumerState<_CallScheduleSheet> {
  bool     _scheduleForLater = false;
  bool     _audioOnly        = false;
  bool     _inviteWali       = true;
  DateTime _scheduledAt      = DateTime.now().add(const Duration(hours: 1));
  bool     _isLoading        = false;

  CallType get _callType => _audioOnly
      ? CallType.audio
      : CallType.videoChaperoned;

  Future<void> _startCall() async {
    setState(() => _isLoading = true);
    Haptic.confirm();

    final callModel = await ref.read(callProvider.notifier).initiateCall(
      matchId:     widget.matchId,
      myName:      widget.myName,
      otherName:   widget.otherName,
      callType:    _callType,
      inviteWali:  _inviteWali,
      scheduledAt: _scheduleForLater ? _scheduledAt : null,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (callModel != null) {
      Navigator.of(context).pop(); // close sheet

      if (!_scheduleForLater) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => InCallScreen(
            callType:  _callType,
            myName:    widget.myName,
            otherName: widget.otherName,
            matchId:   widget.matchId,
          ),
        ));
      } else {
        context.showSuccessSnack(
          'Call scheduled for ${_scheduledAt.shortDate} '
          'at ${_scheduledAt.timeHHMM}. '
          '${widget.otherName} and the guardian will be notified.',
        );
      }
    } else {
      final error = ref.read(callProvider).error;
      if (mounted && error != null) {
        context.showErrorSnack(error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color:        context.surfaceColor,
        borderRadius: AppRadius.bottomSheet,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Handle ────────────────────────────────
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width:  40, height: 4,
                decoration: BoxDecoration(
                  color:        context.handleColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Header — 48px rose circle + title ─────
            Row(children: [
              Container(
                width: 48, height: 48,
                decoration: const BoxDecoration(
                  gradient: AppColors.roseGradient,
                  shape:    BoxShape.circle,
                ),
                child: const Icon(Icons.videocam_rounded,
                  color: AppColors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Call ${widget.otherName}',
                      style: TextStyle(
                        fontFamily:  'Georgia',
                        fontSize:    20,
                        color:       context.onSurface,
                        fontWeight:  FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Chaperoned call — guardian will be notified',
                      style: AppTypography.bodySmall.copyWith(
                        color: context.mutedText),
                    ),
                  ],
                ),
              ),
            ]).animate().fadeIn(duration: 400.ms),

            const SizedBox(height: 24),

            // ── Islamic note — gold tint card ─────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:        AppColors.goldPrimary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.goldPrimary.withOpacity(0.20)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🛡️', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your guardian will be invited to join as an observer. '
                      'This is the blessed way — open communication with family.',
                      style: AppTypography.bodySmall.copyWith(
                        color:  AppColors.goldDark,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate(delay: 100.ms).fadeIn(duration: 350.ms),

            const SizedBox(height: 20),

            // ── Toggle rows with rose switches ────────
            _ToggleTile(
              icon:     Icons.volume_up_rounded,
              label:    'Audio only',
              subtitle: 'No camera — audio call instead',
              value:    _audioOnly,
              onChange: (v) => setState(() => _audioOnly = v),
            ),
            _ToggleTile(
              icon:     Icons.shield_rounded,
              label:    'Invite guardian',
              subtitle: 'Your wali will receive a call invite',
              value:    _inviteWali,
              onChange: (v) => setState(() => _inviteWali = v),
            ),
            _ToggleTile(
              icon:     Icons.schedule_rounded,
              label:    'Schedule for later',
              subtitle: 'Pick a time instead of calling now',
              value:    _scheduleForLater,
              onChange: (v) => setState(() => _scheduleForLater = v),
            ),

            // ── Date picker (slides down when schedule ON) ──
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve:    Curves.easeOutCubic,
              child: _scheduleForLater
                  ? Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: _DateTimePicker(
                        value:    _scheduledAt,
                        onChange: (dt) =>
                            setState(() => _scheduledAt = dt),
                      ).animate()
                          .fadeIn(duration: 300.ms)
                          .slideY(begin: -0.08, end: 0,
                              duration: 350.ms,
                              curve: Curves.easeOutBack),
                    )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 24),

            // ── CTA button ────────────────────────────
            MiskButton(
              label:     _scheduleForLater
                  ? 'Schedule call'
                  : 'Start call now',
              onPressed: _isLoading ? null : _startCall,
              loading:   _isLoading,
              icon:      _scheduleForLater
                  ? Icons.schedule_rounded
                  : Icons.videocam_rounded,
            ).animate(delay: 200.ms)
                .fadeIn(duration: 350.ms)
                .slideY(begin: 0.05, end: 0, duration: 350.ms),

            const SizedBox(height: 10),

            // ── Cancel — ghost button ─────────────────
            MiskButton(
              label:     'Cancel',
              onPressed: () => Navigator.pop(context),
              variant:   MiskButtonVariant.ghost,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TOGGLE TILE
// Icon + label + subtitle, rose-colored switch
// ─────────────────────────────────────────────

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChange,
  });
  final IconData            icon;
  final String              label;
  final String              subtitle;
  final bool                value;
  final void Function(bool) onChange;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SwitchListTile(
        value:          value,
        onChanged:      onChange,
        secondary:      Icon(icon, color: context.mutedText, size: 20),
        title:          Text(label,
          style: AppTypography.bodyMedium.copyWith(
            color: context.onSurface)),
        subtitle:       Text(subtitle,
          style: AppTypography.bodySmall.copyWith(
            color: context.mutedText)),
        activeColor:    AppColors.roseDeep,
        contentPadding: EdgeInsets.zero,
        dense:          true,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// DATE/TIME PICKER
// White card, calendar icon, rose border
// Shows date + time, tappable
// ─────────────────────────────────────────────

class _DateTimePicker extends StatelessWidget {
  const _DateTimePicker({required this.value, required this.onChange});
  final DateTime                value;
  final void Function(DateTime) onChange;

  Future<void> _pick(BuildContext context) async {
    final date = await showDatePicker(
      context:     context,
      initialDate: value,
      firstDate:   DateTime.now(),
      lastDate:    DateTime.now().add(const Duration(days: 30)),
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context:     context,
      initialTime: TimeOfDay.fromDateTime(value),
    );
    if (time == null) return;

    onChange(DateTime(date.year, date.month, date.day,
        time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _pick(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        context.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.roseDeep.withOpacity(0.30)),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today_outlined,
            color: AppColors.roseDeep, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Scheduled time',
                  style: AppTypography.labelSmall.copyWith(
                    color: context.mutedText)),
                Text(
                  '${value.shortDate} at ${value.timeHHMM}',
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.roseDeep),
                ),
              ],
            ),
          ),
          Icon(Icons.edit_outlined,
            color: AppColors.roseDeep, size: 18),
        ]),
      ),
    );
  }
}
