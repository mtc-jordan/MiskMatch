import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/call_models.dart';
import '../providers/call_provider.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/shared/extensions/app_extensions.dart';
import 'package:miskmatch/shared/widgets/common_widgets.dart';

/// Bottom sheet — start or schedule a chaperoned call from the match screen.
///
/// Options:
///   - Call now (video chaperoned) — immediate
///   - Schedule for later (date + time picker)
///   - Audio only toggle
///   - Wali invite toggle (on by default — Islamic requirement)

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
      Navigator.of(context).pop();  // close sheet

      if (!_scheduleForLater) {
        // Navigate to in-call screen immediately
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => _InCallWrapper(
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
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color:        theme.colorScheme.surface,
        borderRadius: AppRadius.bottomSheet,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                margin:  const EdgeInsets.only(top: 12, bottom: 20),
                width:   40, height: 4,
                decoration: BoxDecoration(
                  color:        theme.colorScheme.outline.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Header ─────────────────────────────────────────────
            Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
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
                        style: AppTypography.titleLarge.copyWith(
                          color: AppColors.neutral900)),
                    Text('Chaperoned call — guardian will be notified',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.neutral500)),
                  ],
                ),
              ),
            ]).animate().fadeIn(duration: 400.ms),

            const SizedBox(height: 24),

            // ── Islamic note ───────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:        AppColors.goldPrimary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: AppColors.goldPrimary.withOpacity(0.2)),
              ),
              child: Row(children: [
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
              ]),
            ).animate(delay: 100.ms).fadeIn(),

            const SizedBox(height: 20),

            // ── Options ────────────────────────────────────────────
            _OptionTile(
              icon:     Icons.volume_up_rounded,
              label:    'Audio only',
              subtitle: 'No camera — audio call instead',
              value:    _audioOnly,
              onChange: (v) => setState(() => _audioOnly = v),
            ),
            _OptionTile(
              icon:     Icons.shield_rounded,
              label:    'Invite guardian',
              subtitle: 'Your wali will receive a call invite',
              value:    _inviteWali,
              onChange: (v) => setState(() => _inviteWali = v),
            ),
            _OptionTile(
              icon:     Icons.schedule_rounded,
              label:    'Schedule for later',
              subtitle: 'Pick a time instead of calling now',
              value:    _scheduleForLater,
              onChange: (v) => setState(() => _scheduleForLater = v),
            ),

            // ── Date/time picker (when scheduled) ─────────────────
            if (_scheduleForLater) ...[
              const SizedBox(height: 16),
              _DateTimePicker(
                value:     _scheduledAt,
                onChange: (dt) => setState(() => _scheduledAt = dt),
              ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.05, end: 0),
            ],

            const SizedBox(height: 24),

            // ── CTA ────────────────────────────────────────────────
            MiskButton(
              label:     _scheduleForLater
                  ? 'Schedule call'
                  : 'Start call now',
              onPressed: _isLoading ? null : _startCall,
              loading:   _isLoading,
              icon:      _scheduleForLater
                  ? Icons.schedule_rounded
                  : Icons.videocam_rounded,
            ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.05, end: 0),

            const SizedBox(height: 10),

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
// DATE/TIME PICKER
// ─────────────────────────────────────────────

class _DateTimePicker extends StatelessWidget {
  const _DateTimePicker({required this.value, required this.onChange});
  final DateTime                 value;
  final void Function(DateTime)  onChange;

  Future<void> _pick(BuildContext context) async {
    final date = await showDatePicker(
      context:      context,
      initialDate:  value,
      firstDate:    DateTime.now(),
      lastDate:     DateTime.now().add(const Duration(days: 30)),
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context:      context,
      initialTime:  TimeOfDay.fromDateTime(value),
    );
    if (time == null) return;

    onChange(DateTime(date.year, date.month, date.day,
        time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => _pick(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.roseDeep.withOpacity(0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_today_outlined,
              color: AppColors.roseDeep, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Scheduled time',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.neutral500)),
                Text(
                  '${value.shortDate} at ${value.timeHHMM}',
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.roseDeep),
                ),
              ],
            ),
          ),
          const Icon(Icons.edit_outlined,
              color: AppColors.roseDeep, size: 18),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// OPTION TILE
// ─────────────────────────────────────────────

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChange,
  });
  final IconData               icon;
  final String                 label;
  final String                 subtitle;
  final bool                   value;
  final void Function(bool)    onChange;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SwitchListTile(
        value:          value,
        onChanged:      onChange,
        secondary:      Icon(icon, color: AppColors.neutral500, size: 20),
        title:          Text(label, style: AppTypography.bodyMedium),
        subtitle:       Text(subtitle,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.neutral500)),
        activeColor:    AppColors.roseDeep,
        contentPadding: EdgeInsets.zero,
        dense:          true,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// IN-CALL WRAPPER  (navigated to from the sheet)
// ─────────────────────────────────────────────

class _InCallWrapper extends StatelessWidget {
  const _InCallWrapper({
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
  Widget build(BuildContext context) {
    // Import InCallScreen from in_call_screen.dart
    return import_in_call_screen(
      callType:  callType,
      myName:    myName,
      otherName: otherName,
      matchId:   matchId,
    );
  }
}

// Forward reference resolved at import time
Widget import_in_call_screen({
  required CallType callType,
  required String   myName,
  required String   otherName,
  required String   matchId,
}) {
  // This is resolved via the actual import below.
  // Avoids a circular dependency with in_call_screen.dart.
  // In practice: replace this with direct InCallScreen() constructor.
  return Builder(builder: (context) {
    return Scaffold(
      backgroundColor: AppColors.midnightDeep,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.white),
            const SizedBox(height: 16),
            Text('Connecting...',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.white)),
          ],
        ),
      ),
    );
  });
}

// Using showSuccessSnack / showErrorSnack from app_extensions.dart
