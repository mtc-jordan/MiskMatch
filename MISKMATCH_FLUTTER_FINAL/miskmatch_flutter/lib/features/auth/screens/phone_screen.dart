import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:miskmatch/core/router/app_router.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/shared/widgets/common_widgets.dart';
import '../providers/auth_provider.dart';

/// Combined register/login screen.
/// New users: phone + gender + password → OTP
/// Existing users: phone + password → immediate auth

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen>
    with SingleTickerProviderStateMixin {

  final _formKey    = GlobalKey<FormState>();
  final _phoneCtr   = TextEditingController();
  final _passCtr    = TextEditingController();
  bool  _isRegister = true;
  String _gender    = 'male';
  bool  _obscure    = true;

  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() {
      setState(() => _isRegister = _tabCtrl.index == 0);
    });
  }

  @override
  void dispose() {
    _phoneCtr.dispose();
    _passCtr.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final phone = _phoneCtr.text.trim();
    final pass  = _passCtr.text;
    final notifier = ref.read(authProvider.notifier);

    if (_isRegister) {
      await notifier.register(
        phone:   phone,
        password:pass,
        gender:  _gender,
      );
    } else {
      await notifier.login(phone: phone, password: pass);
    }

    // Navigation handled by GoRouter redirect
  }

  @override
  Widget build(BuildContext context) {
    final auth     = ref.watch(authProvider);
    final isLoading= auth is AuthLoading;
    final error    = auth is AuthError ? auth.error : null;

    // Auto-navigate to OTP when OTP is sent
    ref.listen(authProvider, (_, next) {
      if (next is AuthOtpSent) {
        context.go(
          AppRoutes.otp,
          extra: {'phone': next.phone, 'isNewUser': next.isNewUser},
        );
      }
    });

    return LoadingOverlay(
      isLoading: isLoading,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                // ── Header ──────────────────────────────────────────────
                _Header()
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .slideY(begin: -0.1, end: 0, duration: 500.ms),

                const SizedBox(height: 36),

                // ── Tab bar (Register / Login) ───────────────────────────
                _ModeTab(controller: _tabCtrl)
                    .animate(delay: 100.ms)
                    .fadeIn(duration: 400.ms),

                const SizedBox(height: 28),

                // ── Form ────────────────────────────────────────────────
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Phone field
                      MiskTextField(
                        label:        'Phone number',
                        hint:         '+962 7X XXX XXXX',
                        controller:   _phoneCtr,
                        keyboardType: TextInputType.phone,
                        prefixIcon:   const Icon(Icons.phone_outlined),
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter your phone number';
                          }
                          if (!RegExp(r'^\+\d{7,15}$').hasMatch(v.trim())) {
                            return 'Enter phone with country code, e.g. +962791234567';
                          }
                          return null;
                        },
                      )
                          .animate(delay: 150.ms)
                          .fadeIn(duration: 400.ms)
                          .slideX(begin: -0.05, end: 0),

                      const SizedBox(height: 16),

                      // Password field
                      MiskTextField(
                        label:           'Password',
                        hint:            'At least 8 characters',
                        controller:      _passCtr,
                        obscureText:     _obscure,
                        keyboardType:    TextInputType.visiblePassword,
                        textInputAction: TextInputAction.done,
                        onSubmitted:     (_) => _submit(),
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon:    Icon(_obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                        validator: (v) {
                          if (v == null || v.length < 8) {
                            return 'Password must be at least 8 characters';
                          }
                          return null;
                        },
                      )
                          .animate(delay: 200.ms)
                          .fadeIn(duration: 400.ms)
                          .slideX(begin: -0.05, end: 0),

                      // Gender picker — only for registration
                      if (_isRegister) ...[
                        const SizedBox(height: 20),
                        _GenderPicker(
                          value:    _gender,
                          onChange: (g) => setState(() => _gender = g),
                        )
                            .animate(delay: 250.ms)
                            .fadeIn(duration: 400.ms),
                      ],

                      // Error message
                      if (error != null) ...[
                        const SizedBox(height: 16),
                        _ErrorBanner(message: error.message)
                            .animate()
                            .fadeIn(duration: 300.ms)
                            .shakeX(amount: 4),
                      ],

                      const SizedBox(height: 28),

                      // Submit button
                      MiskButton(
                        label:     _isRegister ? 'Create account' : 'Sign in',
                        onPressed: _submit,
                        loading:   isLoading,
                        icon:      _isRegister
                            ? Icons.arrow_forward_rounded
                            : Icons.login_rounded,
                      )
                          .animate(delay: 300.ms)
                          .fadeIn(duration: 400.ms)
                          .slideY(begin: 0.1, end: 0),

                      const SizedBox(height: 24),

                      // Privacy note
                      _PrivacyNote()
                          .animate(delay: 400.ms)
                          .fadeIn(duration: 400.ms),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SUB-WIDGETS
// ─────────────────────────────────────────────

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: const BoxDecoration(
                gradient: AppColors.roseGradient,
                shape:    BoxShape.circle,
              ),
              child: const Center(
                child: Text('مـ',
                    style: TextStyle(
                      fontFamily: 'Scheherazade',
                      fontSize:   20, color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    )),
              ),
            ),
            const SizedBox(width: 12),
            Text('MiskMatch',
                style: AppTypography.titleLarge.copyWith(
                  color: AppColors.roseDeep,
                  fontWeight: FontWeight.w700,
                )),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Your protected match,\nsealed with barakah.',
          style: AppTypography.headlineSmall.copyWith(
            color:  AppColors.neutral900,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'A marriage platform built on Islamic values.',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.neutral500,
          ),
        ),
      ],
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({required this.controller});
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color:        theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller:         controller,
        indicator:          BoxDecoration(
          color:        theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color:      theme.colorScheme.primary.withOpacity(0.3),
              blurRadius: 8,
              offset:     const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize:      TabBarIndicatorSize.tab,
        labelColor:         theme.colorScheme.onPrimary,
        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
        labelStyle:         AppTypography.labelLarge,
        unselectedLabelStyle: AppTypography.labelLarge.copyWith(
          fontWeight: FontWeight.w400,
        ),
        dividerColor:       Colors.transparent,
        tabs: const [
          Tab(text: 'New account'),
          Tab(text: 'Sign in'),
        ],
      ),
    );
  }
}

class _GenderPicker extends StatelessWidget {
  const _GenderPicker({required this.value, required this.onChange});
  final String                 value;
  final void Function(String)  onChange;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('I am a',
            style: AppTypography.titleSmall.copyWith(
              color: AppColors.neutral700,
            )),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _GenderOption(
                label:    'Brother',
                labelAr:  'أخ',
                icon:     Icons.man_rounded,
                selected: value == 'male',
                onTap:    () => onChange('male'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _GenderOption(
                label:    'Sister',
                labelAr:  'أخت',
                icon:     Icons.woman_rounded,
                selected: value == 'female',
                onTap:    () => onChange('female'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GenderOption extends StatelessWidget {
  const _GenderOption({
    required this.label,
    required this.labelAr,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String   label;
  final String   labelAr;
  final IconData icon;
  final bool     selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surface,
          borderRadius: AppRadius.cardRadius,
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                size:  32,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 6),
            Text(label,
                style: AppTypography.labelLarge.copyWith(
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                )),
            Text(labelAr,
                style: TextStyle(
                  fontFamily: 'Scheherazade',
                  fontSize:   13,
                  color: selected
                      ? theme.colorScheme.primary.withOpacity(0.7)
                      : AppColors.neutral500,
                  height: 1.6,
                )),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        AppColors.errorLight,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.error,
                )),
          ),
        ],
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.shield_outlined, size: 14, color: AppColors.neutral500),
        const SizedBox(width: 6),
        Text(
          'Your data is encrypted and never shared.',
          style: AppTypography.bodySmall.copyWith(color: AppColors.neutral500),
        ),
      ],
    );
  }
}
