import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:miskmatch/features/auth/data/auth_repository.dart';
import 'package:miskmatch/features/auth/providers/auth_provider.dart';
import 'package:miskmatch/shared/models/api_response.dart';
import 'package:miskmatch/features/wali/data/wali_repository.dart';
import 'package:miskmatch/features/wali/providers/wali_provider.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/shared/extensions/app_extensions.dart';
import 'package:miskmatch/shared/widgets/common_widgets.dart';
import 'package:miskmatch/l10n/generated/app_localizations.dart';

/// Settings screen — rosePale bg, Georgia "Settings" roseDeep appbar.
///
/// Sections: Account, Guardian, Appearance, Privacy, About,
/// Quranic tagline, Danger zone.

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _biometricEnabled     = false;
  bool _photoVisible         = false;
  ThemeMode _themeMode       = ThemeMode.system;
  String _appVersion         = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() =>
            _appVersion = 'v${info.version} (${info.buildNumber})');
      }
    } catch (_) {
      if (mounted) setState(() => _appVersion = 'v1.0.0');
    }
  }

  @override
  Widget build(BuildContext context) {
    final waliStatus = ref.watch(waliStatusProvider);

    return Scaffold(
      backgroundColor: context.scaffoldColor,
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(S.of(context).settings,
          style: const TextStyle(
            fontFamily:  'Georgia',
            fontSize:    20,
            color:       AppColors.roseDeep,
            fontWeight:  FontWeight.w700,
          ),
        ),
        backgroundColor: context.scaffoldColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 60),
        children: [
          // ═══════════════════════════════════════════
          // ACCOUNT
          // ═══════════════════════════════════════════
          _SectionHeader(icon: Icons.person_outline_rounded, label: S.of(context).account),

          _SettingsTile(
            icon:     Icons.phone_outlined,
            label:    S.of(context).phoneNumber,
            trailing: Text('+•••••••••••',
              style: AppTypography.bodySmall.copyWith(
                color: context.mutedText)),
          ),

          _SwitchTile(
            icon:     Icons.notifications_outlined,
            label:    S.of(context).pushNotifications,
            subtitle: S.of(context).pushNotificationsDesc,
            value:    _notificationsEnabled,
            onChange: (v) => setState(() => _notificationsEnabled = v),
          ),

          _SwitchTile(
            icon:     Icons.fingerprint_rounded,
            label:    S.of(context).biometricLock,
            subtitle: 'Require Face ID / fingerprint on open',
            value:    _biometricEnabled,
            onChange: (v) => setState(() => _biometricEnabled = v),
          ),

          const SizedBox(height: 12),

          // ═══════════════════════════════════════════
          // GUARDIAN (WALI)
          // ═══════════════════════════════════════════
          _SectionHeader(icon: Icons.shield_outlined, label: S.of(context).guardianWali),

          _GuardianStatusTile(
            waliStatus: waliStatus,
            onResend: () async {
              await ref.read(waliRepositoryProvider).resendInvite();
              if (context.mounted) {
                context.showSuccessSnack('Invitation resent.');
              }
            },
          ),

          const SizedBox(height: 12),

          // ═══════════════════════════════════════════
          // APPEARANCE
          // ═══════════════════════════════════════════
          _SectionHeader(icon: Icons.palette_outlined, label: S.of(context).appearance),

          _ThemeSegmentTile(
            themeMode: _themeMode,
            onChanged: (m) => setState(() => _themeMode = m),
          ),

          const SizedBox(height: 12),

          // ═══════════════════════════════════════════
          // PRIVACY
          // ═══════════════════════════════════════════
          _SectionHeader(icon: Icons.lock_outline_rounded, label: S.of(context).privacy),

          _SwitchTile(
            icon:     Icons.photo_outlined,
            label:    S.of(context).showPhotoBeforeMutual,
            subtitle: 'Off — photo revealed only after both sides show interest',
            value:    _photoVisible,
            onChange: (v) => setState(() => _photoVisible = v),
          ),

          const SizedBox(height: 12),

          // ═══════════════════════════════════════════
          // ABOUT
          // ═══════════════════════════════════════════
          _SectionHeader(icon: Icons.info_outline_rounded, label: S.of(context).about),

          _SettingsTile(
            icon:     Icons.info_outline_rounded,
            label:    S.of(context).version,
            trailing: Text(_appVersion,
              style: AppTypography.bodySmall.copyWith(
                color: context.mutedText)),
          ),

          _SettingsTile(
            icon:  Icons.description_outlined,
            label: S.of(context).termsOfService,
            onTap: () {},
          ),

          _SettingsTile(
            icon:  Icons.privacy_tip_outlined,
            label: S.of(context).privacyPolicy,
            onTap: () {},
          ),

          _SettingsTile(
            icon:  Icons.email_outlined,
            label: S.of(context).contactSupport,
            onTap: () {},
          ),

          _SettingsTile(
            icon:  Icons.star_outline_rounded,
            label: S.of(context).rateMiskMatch,
            onTap: () {},
          ),

          // ═══════════════════════════════════════════
          // QURANIC TAGLINE
          // ═══════════════════════════════════════════
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Center(
              child: Column(children: [
                Text(
                  S.of(context).sealIsMusk,
                  style: const TextStyle(
                    fontFamily: 'Scheherazade',
                    fontSize:   18,
                    color:      AppColors.goldPrimary,
                    height:     2.0,
                  ),
                ),
                Text(
                  S.of(context).sealIsMuskTranslation,
                  style: AppTypography.bodySmall.copyWith(
                    color:     context.mutedText,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ]),
            ),
          ).animate(delay: 200.ms).fadeIn(duration: 400.ms),

          const SizedBox(height: 12),

          // ═══════════════════════════════════════════
          // DANGER ZONE
          // ═══════════════════════════════════════════
          _SectionHeader(icon: Icons.warning_amber_rounded, label: S.of(context).accountActions),

          _SettingsTile(
            icon:      Icons.logout_rounded,
            label:     S.of(context).signOut,
            textColor: AppColors.error,
            onTap:     () => _showLogoutSheet(context, ref),
          ),

          _SettingsTile(
            icon:      Icons.delete_forever_outlined,
            label:     S.of(context).deleteAccount,
            textColor: AppColors.error,
            onTap:     () => _showDeleteSheet(context),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── Logout confirmation sheet ──────────────────
  void _showLogoutSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context:         context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmSheet(
        icon:      Icons.logout_rounded,
        title:     '${S.of(context).signOut}?',
        body:      S.of(context).signOutBody,
        confirm:   S.of(context).signOut,
        isDanger:  false,
        onConfirm: () async {
          Navigator.pop(context);
          await ref.read(authProvider.notifier).logout();
        },
      ),
    );
  }

  // ── Delete account confirmation sheet ──────────
  void _showDeleteSheet(BuildContext context) {
    showModalBottomSheet(
      context:         context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmSheet(
        icon:      Icons.warning_amber_rounded,
        iconColor: AppColors.error,
        title:     '${S.of(context).deleteAccount}?',
        body:      S.of(context).deleteAccountWarning,
        confirm:   S.of(context).deleteMyAccount,
        isDanger:  true,
        onConfirm: () async {
          Navigator.pop(context);
          final result = await ref.read(authRepositoryProvider).deleteAccount();
          if (!mounted) return;
          result.when(
            success: (_) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Account deleted successfully.')),
              );
              ref.read(authProvider.notifier).logout();
            },
            error: (err) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(err.message)),
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SECTION HEADER
// emoji + label uppercase 11pt neutral500
// letterSpacing 0.8, no dividers — spacing only
// ─────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});
  final IconData icon;
  final String   label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Row(children: [
        Icon(icon, size: 16, color: context.mutedText),
        const SizedBox(width: 8),
        Text(label.toUpperCase(),
          style: TextStyle(
            fontSize:       11,
            color:          context.mutedText,
            fontWeight:     FontWeight.w600,
            letterSpacing:  0.8,
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// SETTING TILE
// 56px height, 20px icon neutral500
// 15pt label neutral900
// Optional subtitle 11pt neutral500
// Trailing: chevron if tappable, or custom widget
// Rose tint ripple on tap
// ─────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.textColor,
  });

  final IconData      icon;
  final String        label;
  final String?       subtitle;
  final Widget?       trailing;
  final VoidCallback? onTap;
  final Color?        textColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap:       onTap,
        splashColor: AppColors.roseDeep.withOpacity(0.08),
        highlightColor: AppColors.roseDeep.withOpacity(0.04),
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Icon(icon,
                size:  20,
                color: textColor ?? context.mutedText,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                      style: TextStyle(
                        fontSize: 15,
                        color:    textColor ?? context.onSurface,
                      ),
                    ),
                    if (subtitle != null)
                      Text(subtitle!,
                        style: TextStyle(
                          fontSize: 11,
                          color:    context.mutedText,
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ] else if (onTap != null)
                Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                  color: context.handleColor, size: 18),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SWITCH TILE
// Same layout as SettingsTile but trailing is
// custom Switch: thumb white, track filled roseDeep,
// track empty neutral300, 300ms cubic transition
// ─────────────────────────────────────────────

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChange,
    this.subtitle,
  });

  final IconData            icon;
  final String              label;
  final String?             subtitle;
  final bool                value;
  final void Function(bool) onChange;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          Icon(icon, size: 20, color: context.mutedText),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                  style: TextStyle(
                    fontSize: 15,
                    color:    context.onSurface,
                  ),
                ),
                if (subtitle != null)
                  Text(subtitle!,
                    style: TextStyle(
                      fontSize: 11,
                      color:    context.mutedText,
                    ),
                  ),
              ],
            ),
          ),
          Switch.adaptive(
            value:            value,
            onChanged:        onChange,
            activeColor:      AppColors.roseDeep,
            activeTrackColor: AppColors.roseDeep,
            inactiveThumbColor: AppColors.white,
            inactiveTrackColor: context.handleColor,
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// THEME SEGMENT BUTTON
// SegmentedButton 3 options:
//   ☀️ Light | Auto | 🌙 Dark
// Selected: rose filled, white icon
// Visual density compact
// ─────────────────────────────────────────────

class _ThemeSegmentTile extends StatelessWidget {
  const _ThemeSegmentTile({
    required this.themeMode,
    required this.onChanged,
  });
  final ThemeMode                 themeMode;
  final void Function(ThemeMode)  onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          Icon(Icons.palette_outlined,
            color: context.mutedText, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Theme',
                  style: TextStyle(
                    fontSize: 15,
                    color:    context.onSurface,
                  ),
                ),
                Text('Rose Garden / Musk Night',
                  style: TextStyle(
                    fontSize: 11,
                    color:    context.mutedText,
                  ),
                ),
              ],
            ),
          ),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.light,
                label: Icon(Icons.light_mode_outlined, size: 16),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                label: Icon(Icons.brightness_auto_outlined, size: 16),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Icon(Icons.dark_mode_outlined, size: 16),
              ),
            ],
            selected:            {themeMode},
            onSelectionChanged:  (s) => onChanged(s.first),
            showSelectedIcon:    false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.roseDeep;
                }
                return Colors.transparent;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.white;
                }
                return context.mutedText;
              }),
              side: WidgetStateProperty.all(
                BorderSide(color: AppColors.roseDeep.withOpacity(0.3)),
              ),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              ),
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// GUARDIAN STATUS TILE
// Live AsyncValue from provider
// Status chip: "Active" green / "Pending" gold / "Not set up" neutral
// Resend invite option when pending
// ─────────────────────────────────────────────

class _GuardianStatusTile extends StatelessWidget {
  const _GuardianStatusTile({
    required this.waliStatus,
    required this.onResend,
  });
  final AsyncValue<dynamic> waliStatus;
  final VoidCallback        onResend;

  @override
  Widget build(BuildContext context) {
    return waliStatus.when(
      loading: () => SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                color: context.mutedText, strokeWidth: 2),
            ),
            const SizedBox(width: 14),
            Text('Loading guardian status...',
              style: TextStyle(fontSize: 15, color: context.mutedText)),
          ]),
        ),
      ),
      error: (_, __) => _SettingsTile(
        icon:     Icons.shield_outlined,
        label:    'Guardian status',
        trailing: _buildChip('Not set up', AppColors.neutral500),
      ),
      data: (status) => Column(children: [
        _SettingsTile(
          icon:     status.accepted
              ? Icons.shield_rounded
              : Icons.shield_outlined,
          label:    'Guardian',
          subtitle: status.waliName,
          trailing: _buildChip(
            !status.hasWali
                ? 'Not set up'
                : status.accepted
                    ? 'Active'
                    : 'Pending',
            !status.hasWali
                ? AppColors.neutral500
                : status.accepted
                    ? AppColors.success
                    : AppColors.goldDark,
          ),
        ),
        if (status.hasWali && !status.accepted)
          _SettingsTile(
            icon:  Icons.send_rounded,
            label: 'Resend guardian invite',
            onTap: onResend,
          ),
      ]),
    );
  }

  Widget _buildChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(text,
        style: TextStyle(
          fontSize:   11,
          color:      color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CONFIRM SHEET (logout / delete)
// Handle, emoji 44pt spring scale, Georgia title,
// body text, confirm button (error or neutral),
// cancel ghost
// ─────────────────────────────────────────────

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.icon,
    this.iconColor,
    required this.title,
    required this.body,
    required this.confirm,
    required this.onConfirm,
    required this.isDanger,
  });

  final IconData     icon;
  final Color?       iconColor;
  final String       title;
  final String       body;
  final String       confirm;
  final VoidCallback onConfirm;
  final bool         isDanger;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        context.surfaceColor,
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
            color:        context.handleColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Icon — spring scale
        Icon(icon, size: 44, color: iconColor ?? context.onSurface)
            .animate()
            .scaleXY(begin: 0.5, end: 1.0,
                duration: 500.ms,
                curve: Curves.easeOutBack),

        const SizedBox(height: 16),

        // Title — Georgia
        Text(title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily:  'Georgia',
            fontSize:    22,
            color:       context.onSurface,
            fontWeight:  FontWeight.w700,
          ),
        ),

        const SizedBox(height: 8),

        // Body
        Text(body,
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(
            color:  context.mutedText,
            height: 1.6,
          ),
        ),

        const SizedBox(height: 28),

        // Confirm button
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: isDanger
                  ? AppColors.error
                  : context.onSurface,
              foregroundColor: AppColors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(confirm,
              style: const TextStyle(
                fontSize:   15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Cancel — ghost
        MiskButton(
          label:     S.of(context).cancel,
          onPressed: () => Navigator.pop(context),
          variant:   MiskButtonVariant.ghost,
        ),
      ]),
    );
  }
}
