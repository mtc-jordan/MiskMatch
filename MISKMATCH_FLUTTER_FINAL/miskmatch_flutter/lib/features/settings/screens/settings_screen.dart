import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:miskmatch/features/auth/providers/auth_provider.dart';
import 'package:miskmatch/features/wali/data/wali_repository.dart';
import 'package:miskmatch/features/wali/providers/wali_provider.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/shared/widgets/common_widgets.dart';

/// App Settings screen — accessible from Profile tab → settings icon.
///
/// Sections:
///   Account      — phone, notifications, biometric lock
///   Guardian     — wali status quick view, invite resend
///   Appearance   — theme toggle (Light / Dark / System)
///   Privacy      — photo visibility, voice visibility
///   About        — version, terms, privacy policy, contact
///   Danger zone  — logout, delete account

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
      setState(() => _appVersion = 'v1.0.0');
    }
  }

  @override
  Widget build(BuildContext context) {
    final waliStatus = ref.watch(waliStatusProvider);
    final auth       = ref.watch(authProvider);
    final phone      = auth is AuthAuthenticated ? '' : '';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: const BackButton(),
        title: Text('Settings',
            style: AppTypography.titleLarge.copyWith(
              color: AppColors.roseDeep, fontWeight: FontWeight.w700)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 60),
        children: [
          // ── ACCOUNT ──────────────────────────────────────────────
          _SectionHeader(title: 'Account', icon: '👤'),

          _SettingsTile(
            icon:     Icons.phone_outlined,
            label:    'Phone number',
            trailing: Text(phone.isNotEmpty ? phone : '+•••••••••••',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.neutral500)),
          ),

          _SwitchTile(
            icon:     Icons.notifications_outlined,
            label:    'Push notifications',
            subtitle: 'New matches, messages, game turns',
            value:    _notificationsEnabled,
            onChange: (v) => setState(() => _notificationsEnabled = v),
          ),

          _SwitchTile(
            icon:     Icons.fingerprint_rounded,
            label:    'Biometric lock',
            subtitle: 'Require Face ID / fingerprint on open',
            value:    _biometricEnabled,
            onChange: (v) => setState(() => _biometricEnabled = v),
          ),

          const _Divider(),

          // ── GUARDIAN ─────────────────────────────────────────────
          _SectionHeader(title: 'Guardian (Wali)', icon: '🛡️'),

          waliStatus.when(
            loading: () => const _LoadingTile(),
            error:   (_, __) => _SettingsTile(
              icon:     Icons.shield_outlined,
              label:    'Guardian status',
              trailing: const Text('Not set up',
                  style: TextStyle(color: AppColors.neutral500)),
              onTap:    () {},
            ),
            data: (status) => Column(children: [
              _SettingsTile(
                icon:     status.accepted
                    ? Icons.shield_rounded
                    : Icons.shield_outlined,
                label:    'Guardian',
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: status.accepted
                          ? AppColors.success.withOpacity(0.1)
                          : AppColors.goldPrimary.withOpacity(0.1),
                      borderRadius: AppRadius.chipRadius,
                    ),
                    child: Text(
                      !status.hasWali
                          ? 'Not set up'
                          : status.accepted
                              ? 'Active'
                              : 'Pending',
                      style: AppTypography.labelSmall.copyWith(
                        color: !status.hasWali
                            ? AppColors.neutral500
                            : status.accepted
                                ? AppColors.success
                                : AppColors.goldDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ]),
                subtitle: status.waliName,
              ),
              if (status.hasWali && !status.accepted)
                _SettingsTile(
                  icon:     Icons.send_rounded,
                  label:    'Resend guardian invite',
                  onTap:    () async {
                    await ref.read(waliRepositoryProvider).resendInvite();
                    if (context.mounted) {
                      context.showSuccessSnack('Invitation resent.');
                    }
                  },
                ),
            ]),
          ),

          const _Divider(),

          // ── APPEARANCE ────────────────────────────────────────────
          _SectionHeader(title: 'Appearance', icon: '🎨'),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Row(children: [
              const Icon(Icons.palette_outlined,
                  color: AppColors.neutral500, size: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Theme',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.neutral900)),
                    Text('Rose Garden / Musk Night',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.neutral500)),
                  ],
                ),
              ),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon:  Icon(Icons.light_mode_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon:  Icon(Icons.brightness_auto_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon:  Icon(Icons.dark_mode_rounded, size: 16),
                  ),
                ],
                selected:      {_themeMode},
                onSelectionChanged: (s) =>
                    setState(() => _themeMode = s.first),
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ]),
          ),

          const _Divider(),

          // ── PRIVACY ───────────────────────────────────────────────
          _SectionHeader(title: 'Privacy', icon: '🔒'),

          _SwitchTile(
            icon:     Icons.photo_outlined,
            label:    'Show photo before mutual interest',
            subtitle: 'Off — photo revealed only after both sides show interest',
            value:    _photoVisible,
            onChange: (v) => setState(() => _photoVisible = v),
          ),

          const _Divider(),

          // ── ABOUT ─────────────────────────────────────────────────
          _SectionHeader(title: 'About', icon: 'ℹ️'),

          _SettingsTile(
            icon:     Icons.info_outline_rounded,
            label:    'Version',
            trailing: Text(_appVersion,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.neutral500)),
          ),

          _SettingsTile(
            icon:  Icons.description_outlined,
            label: 'Terms of service',
            onTap: () {}, // URL launcher
          ),

          _SettingsTile(
            icon:  Icons.privacy_tip_outlined,
            label: 'Privacy policy',
            onTap: () {},
          ),

          _SettingsTile(
            icon:  Icons.email_outlined,
            label: 'Contact support',
            onTap: () {},
          ),

          _SettingsTile(
            icon:  Icons.star_outline_rounded,
            label: 'Rate MiskMatch',
            onTap: () {},
          ),

          // ── Quran reference ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Center(
              child: Column(children: [
                const Text(
                  'ختامه مسك',
                  style: TextStyle(
                    fontFamily: 'Scheherazade',
                    fontSize:   18,
                    color:      AppColors.goldPrimary,
                    height:     2.0,
                  ),
                ),
                Text(
                  '"Its seal is musk." — Quran 83:26',
                  style: AppTypography.bodySmall.copyWith(
                    color:     AppColors.neutral500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ]),
            ),
          ).animate(delay: 200.ms).fadeIn(),

          const _Divider(),

          // ── DANGER ZONE ───────────────────────────────────────────
          _SectionHeader(title: 'Account actions', icon: '⚠️'),

          _SettingsTile(
            icon:      Icons.logout_rounded,
            label:     'Sign out',
            textColor: AppColors.error,
            onTap:     () => _showLogoutSheet(context, ref),
          ),

          _SettingsTile(
            icon:      Icons.delete_forever_outlined,
            label:     'Delete account',
            textColor: AppColors.error,
            onTap:     () => _showDeleteSheet(context),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showLogoutSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context:         context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmSheet(
        emoji:    '🚪',
        title:    'Sign out?',
        body:     'You can sign back in with your phone number at any time.',
        confirm:  'Sign out',
        onConfirm: () async {
          Navigator.pop(context);
          await ref.read(authProvider.notifier).logout();
        },
        isDanger: false,
      ),
    );
  }

  void _showDeleteSheet(BuildContext context) {
    showModalBottomSheet(
      context:         context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmSheet(
        emoji:    '⚠️',
        title:    'Delete account?',
        body:     'This permanently deletes your profile, matches, and all '
                  'conversation history. This cannot be undone.',
        confirm:  'Delete my account',
        onConfirm: () {
          Navigator.pop(context);
          // TODO: implement delete account API call
        },
        isDanger: true,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SECTION HEADER
// ─────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});
  final String title;
  final String icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Text(title.toUpperCase(),
            style: AppTypography.labelSmall.copyWith(
              color:       AppColors.neutral500,
              letterSpacing: 0.8,
              fontWeight:  FontWeight.w600,
            )),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// SETTINGS TILE
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

  final IconData icon;
  final String   label;
  final String?  subtitle;
  final Widget?  trailing;
  final VoidCallback? onTap;
  final Color?   textColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(children: [
            Icon(icon,
                size:  20,
                color: textColor ?? AppColors.neutral500),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTypography.bodyMedium.copyWith(
                      color: textColor ?? theme.colorScheme.onSurface)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.neutral500)),
              ],
            )),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ] else if (onTap != null)
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.neutral300, size: 18),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SWITCH TILE
// ─────────────────────────────────────────────

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChange,
    this.subtitle,
  });

  final IconData icon;
  final String   label;
  final String?  subtitle;
  final bool     value;
  final void Function(bool) onChange;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(children: [
        Icon(icon, size: 20, color: AppColors.neutral500),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTypography.bodyMedium),
            if (subtitle != null)
              Text(subtitle!,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.neutral500)),
          ],
        )),
        Switch(
          value:       value,
          onChanged:   onChange,
          activeColor: AppColors.roseDeep,
        ),
      ]),
    );
  }
}

class _LoadingTile extends StatelessWidget {
  const _LoadingTile();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(children: [
        SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(
              color: AppColors.neutral500, strokeWidth: 2),
        ),
        SizedBox(width: 14),
        Text('Loading guardian status...'),
      ]),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 20, endIndent: 20,
      color: Theme.of(context).colorScheme.outline.withOpacity(0.15),
    );
  }
}

// ─────────────────────────────────────────────
// CONFIRM SHEET
// ─────────────────────────────────────────────

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.emoji,
    required this.title,
    required this.body,
    required this.confirm,
    required this.onConfirm,
    required this.isDanger,
  });

  final String   emoji;
  final String   title;
  final String   body;
  final String   confirm;
  final VoidCallback onConfirm;
  final bool     isDanger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color:        theme.colorScheme.surface,
        borderRadius: AppRadius.bottomSheet,
      ),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          margin:  const EdgeInsets.only(top: 12, bottom: 20),
          width:   40, height: 4,
          decoration: BoxDecoration(
            color:        theme.colorScheme.outline.withOpacity(0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Text(emoji, style: const TextStyle(fontSize: 44)),
        const SizedBox(height: 16),
        Text(title,
            style: AppTypography.headlineSmall,
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(body,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.neutral500, height: 1.6)),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity, height: 56,
          child: ElevatedButton(
            onPressed: onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: isDanger ? AppColors.error : AppColors.roseDeep,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.buttonRadius),
            ),
            child: Text(confirm,
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.white, fontSize: 15)),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// BuildContext extension (local import avoidance)
// ─────────────────────────────────────────────

extension _ContextX on BuildContext {
  void showSuccessSnack(String msg) {
    ScaffoldMessenger.of(this).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: AppColors.success,
      behavior:        SnackBarBehavior.floating,
    ));
  }
}
