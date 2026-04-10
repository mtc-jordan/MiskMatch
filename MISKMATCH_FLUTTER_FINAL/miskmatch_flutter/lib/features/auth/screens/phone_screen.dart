import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:miskmatch/core/router/app_router.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/shared/widgets/common_widgets.dart';
import '../providers/auth_provider.dart';

/// Combined register / login screen.
/// New users: phone + gender + password → OTP
/// Existing users: phone + password → immediate auth

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen>
    with SingleTickerProviderStateMixin {
  final _formKey  = GlobalKey<FormState>();
  final _phoneCtr = TextEditingController();
  final _passCtr  = TextEditingController();
  bool   _isRegister = true;
  String _gender     = 'male';
  bool   _obscure    = true;
  String _dialCode   = '+962';
  String _flag       = '🇯🇴';

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

  String get _fullPhone => '$_dialCode${_phoneCtr.text.replaceAll(' ', '').trim()}';

  bool get _phoneValid => _phoneCtr.text.replaceAll(' ', '').trim().length >= 8;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();

    final phone = _fullPhone;
    final pass  = _passCtr.text;
    final notifier = ref.read(authProvider.notifier);

    if (_isRegister) {
      await notifier.register(phone: phone, password: pass, gender: _gender);
    } else {
      await notifier.login(phone: phone, password: pass);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth      = ref.watch(authProvider);
    final isLoading = auth is AuthLoading;
    final error     = auth is AuthError ? auth.error : null;
    final mq        = MediaQuery.of(context);

    ref.listen(authProvider, (_, next) {
      if (next is AuthOtpSent) {
        context.go(AppRoutes.otp,
            extra: {'phone': next.phone, 'isNewUser': next.isNewUser});
      }
    });

    return LoadingOverlay(
      isLoading: isLoading,
      child: Scaffold(
        backgroundColor: context.scaffoldColor,
        body: SingleChildScrollView(
          child: Column(
            children: [
              // ── Hero gradient top section ──────────────────────────────
              _HeroSection(height: mq.size.height * 0.38),

              // ── Content card sliding up ────────────────────────────────
              Transform.translate(
                offset: const Offset(0, -32),
                child: _ContentCard(
                  formKey:    _formKey,
                  tabCtrl:    _tabCtrl,
                  phoneCtr:   _phoneCtr,
                  passCtr:    _passCtr,
                  isRegister: _isRegister,
                  gender:     _gender,
                  obscure:    _obscure,
                  dialCode:   _dialCode,
                  flag:       _flag,
                  phoneValid: _phoneValid,
                  isLoading:  isLoading,
                  error:      error,
                  onGender:   (g) => setState(() => _gender = g),
                  onObscure:  ()  => setState(() => _obscure = !_obscure),
                  onCountry:  (code, flag) =>
                      setState(() { _dialCode = code; _flag = flag; }),
                  onSubmit:   _submit,
                  onPhoneChanged: (_) => setState(() {}),
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 100.ms)
                    .slideY(begin: 0.08, end: 0,
                            duration: 400.ms, curve: Curves.easeOutCubic),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HERO SECTION — gradient header
// ─────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      height: height,
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.only(
          bottomLeft:  Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // مـ logo circle
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  gradient: AppColors.roseGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.roseDeep.withOpacity(0.4),
                      blurRadius: 20, offset: const Offset(0, 6)),
                  ],
                ),
                child: const Center(
                  child: Text('مـ',
                    style: TextStyle(
                      fontFamily: 'Scheherazade', fontSize: 36,
                      color: AppColors.white, fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
              )
                  .animate()
                  .scale(begin: const Offset(0.5, 0.5), end: const Offset(1, 1),
                         duration: 500.ms, curve: Curves.elasticOut)
                  .fadeIn(duration: 300.ms),

              const Spacer(),

              // Headline
              const Text(
                'Find your\nother half.',
                style: TextStyle(
                  fontFamily: 'Georgia', fontSize: 36,
                  fontWeight: FontWeight.w700, color: AppColors.white,
                  height: 1.2,
                ),
              )
                  .animate(delay: 200.ms)
                  .fadeIn(duration: 500.ms)
                  .slideY(begin: 0.1, end: 0, duration: 500.ms,
                          curve: Curves.easeOutCubic),

              const SizedBox(height: 10),

              Text(
                'The Islamic way — with your guardian\'s blessing.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.neutral300, fontStyle: FontStyle.italic),
              )
                  .animate(delay: 350.ms)
                  .fadeIn(duration: 400.ms),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CONTENT CARD
// ─────────────────────────────────────────────

class _ContentCard extends StatelessWidget {
  const _ContentCard({
    required this.formKey,
    required this.tabCtrl,
    required this.phoneCtr,
    required this.passCtr,
    required this.isRegister,
    required this.gender,
    required this.obscure,
    required this.dialCode,
    required this.flag,
    required this.phoneValid,
    required this.isLoading,
    required this.error,
    required this.onGender,
    required this.onObscure,
    required this.onCountry,
    required this.onSubmit,
    required this.onPhoneChanged,
  });

  final GlobalKey<FormState>    formKey;
  final TabController           tabCtrl;
  final TextEditingController   phoneCtr, passCtr;
  final bool                    isRegister, obscure, phoneValid, isLoading;
  final String                  gender, dialCode, flag;
  final dynamic                 error;
  final void Function(String)   onGender;
  final VoidCallback            onObscure;
  final void Function(String, String) onCountry;
  final VoidCallback            onSubmit;
  final void Function(String)   onPhoneChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.only(
          topLeft:  Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: context.isDark
            ? []
            : const [
                BoxShadow(
                  color: Color(0x148B1A4A),
                  blurRadius: 32, offset: Offset(0, -8)),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text('Enter your number',
                style: AppTypography.titleLarge.copyWith(
                  fontSize: 20, fontWeight: FontWeight.w700,
                  color: context.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text('We\'ll send a verification code via SMS',
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 13, color: context.mutedText),
              ),

              const SizedBox(height: 20),

              // Tab bar (Register / Login)
              _ModeTab(controller: tabCtrl),

              const SizedBox(height: 24),

              // Country picker + phone
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Country chip
                  GestureDetector(
                    onTap: () => _showCountryPicker(context),
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.roseLight.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(AppRadius.input),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(flag, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 6),
                          Text(dialCode,
                            style: AppTypography.bodyLarge.copyWith(
                              fontWeight: FontWeight.w600,
                              color: context.onSurface),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.keyboard_arrow_down_rounded,
                              size: 18, color: context.mutedText),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Phone field
                  Expanded(
                    child: MiskTextField(
                      label:        'Phone number',
                      hint:         '79 123 4567',
                      controller:   phoneCtr,
                      keyboardType: TextInputType.phone,
                      autofocus:    true,
                      textInputAction: TextInputAction.next,
                      onChanged:    onPhoneChanged,
                      validator: (v) {
                        if (v == null || v.replaceAll(' ', '').trim().length < 8) {
                          return 'Enter a valid phone number';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Password field
              MiskTextField(
                label:           'Password',
                hint:            'At least 8 characters',
                controller:      passCtr,
                obscureText:     obscure,
                keyboardType:    TextInputType.visiblePassword,
                textInputAction: TextInputAction.done,
                onSubmitted:     (_) => onSubmit(),
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: onObscure,
                ),
                validator: (v) {
                  if (v == null || v.length < 8) {
                    return 'Password must be at least 8 characters';
                  }
                  return null;
                },
              ),

              // Gender picker (register only)
              if (isRegister) ...[
                const SizedBox(height: 20),
                _GenderPicker(value: gender, onChange: onGender),
              ],

              // Error
              if (error != null) ...[
                const SizedBox(height: 16),
                _ErrorBanner(message: error.message)
                    .animate()
                    .fadeIn(duration: 300.ms)
                    .shakeX(amount: 4),
              ],

              const SizedBox(height: 28),

              // Submit
              MiskButton(
                label:     isRegister ? 'Create account' : 'Sign in',
                onPressed: phoneValid ? onSubmit : null,
                loading:   isLoading,
                icon:      isRegister
                    ? Icons.arrow_forward_rounded
                    : Icons.login_rounded,
              ),

              const SizedBox(height: 20),

              // Terms
              Center(
                child: Text.rich(
                  TextSpan(
                    style: AppTypography.caption.copyWith(color: context.mutedText),
                    children: [
                      const TextSpan(text: 'By continuing you agree to our '),
                      TextSpan(text: 'Terms',
                        style: TextStyle(color: AppColors.roseDeep, fontWeight: FontWeight.w600)),
                      const TextSpan(text: ' & '),
                      TextSpan(text: 'Privacy Policy',
                        style: TextStyle(color: AppColors.roseDeep, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 16),

              // Islamic note
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mosque_rounded,
                        size: 14, color: context.mutedText.withOpacity(0.7)),
                    const SizedBox(width: 6),
                    Text('Your guardian will be kept informed',
                      style: AppTypography.caption.copyWith(
                        fontSize: 9, color: context.mutedText,
                        fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showCountryPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.bottomSheet,
      ),
      builder: (_) => _CountryPickerSheet(
        onSelect: (code, flag) {
          onCountry(code, flag);
          Navigator.pop(context);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// MODE TAB (Register / Login)
// ─────────────────────────────────────────────

class _ModeTab extends StatelessWidget {
  const _ModeTab({required this.controller});
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color:        context.subtleBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller:           controller,
        indicator: BoxDecoration(
          gradient:     AppColors.roseGradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.roseDeep.withOpacity(0.25),
              blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        indicatorSize:        TabBarIndicatorSize.tab,
        labelColor:           AppColors.white,
        unselectedLabelColor: context.mutedText,
        labelStyle:           AppTypography.labelLarge.copyWith(fontSize: 13),
        unselectedLabelStyle: AppTypography.labelMedium.copyWith(
            fontWeight: FontWeight.w400),
        dividerColor:         Colors.transparent,
        tabs: const [
          Tab(text: 'New account'),
          Tab(text: 'Sign in'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// GENDER PICKER
// ─────────────────────────────────────────────

class _GenderPicker extends StatelessWidget {
  const _GenderPicker({required this.value, required this.onChange});
  final String                value;
  final void Function(String) onChange;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('I am a',
          style: AppTypography.titleSmall.copyWith(color: context.subtleText)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _GenderOption(
              label: 'Brother', labelAr: 'أخ', icon: Icons.man_rounded,
              selected: value == 'male', onTap: () => onChange('male'))),
            const SizedBox(width: 12),
            Expanded(child: _GenderOption(
              label: 'Sister', labelAr: 'أخت', icon: Icons.woman_rounded,
              selected: value == 'female', onTap: () => onChange('female'))),
          ],
        ),
      ],
    );
  }
}

class _GenderOption extends StatelessWidget {
  const _GenderOption({
    required this.label, required this.labelAr, required this.icon,
    required this.selected, required this.onTap,
  });

  final String label, labelAr;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.roseDeep.withOpacity(0.08)
              : context.surfaceColor,
          borderRadius: AppRadius.cardRadius,
          border: Border.all(
            color: selected
                ? AppColors.roseDeep
                : context.isDark ? AppColors.neutral700 : AppColors.neutral300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32,
              color: selected ? AppColors.roseDeep : context.mutedText),
            const SizedBox(height: 6),
            Text(label,
              style: AppTypography.labelLarge.copyWith(
                fontSize: 14,
                color: selected ? AppColors.roseDeep : context.onSurface)),
            Text(labelAr,
              style: TextStyle(
                fontFamily: 'Scheherazade', fontSize: 13,
                color: selected
                    ? AppColors.roseDeep.withOpacity(0.7)
                    : context.mutedText,
                height: 1.6,
              )),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// COUNTRY PICKER SHEET
// ─────────────────────────────────────────────

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet({required this.onSelect});
  final void Function(String code, String flag) onSelect;

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  String _query = '';

  static const _countries = [
    ('🇯🇴', 'Jordan',         '+962'),
    ('🇸🇦', 'Saudi Arabia',   '+966'),
    ('🇦🇪', 'UAE',            '+971'),
    ('🇪🇬', 'Egypt',          '+20'),
    ('🇬🇧', 'United Kingdom', '+44'),
    ('🇺🇸', 'United States',  '+1'),
    ('🇨🇦', 'Canada',         '+1'),
    ('🇲🇾', 'Malaysia',       '+60'),
    ('🇹🇷', 'Turkey',         '+90'),
    ('🇩🇪', 'Germany',        '+49'),
    ('🇫🇷', 'France',         '+33'),
    ('🇦🇺', 'Australia',      '+61'),
    ('🇵🇰', 'Pakistan',       '+92'),
    ('🇮🇳', 'India',          '+91'),
    ('🇮🇩', 'Indonesia',      '+62'),
    ('🇰🇼', 'Kuwait',         '+965'),
    ('🇶🇦', 'Qatar',          '+974'),
    ('🇧🇭', 'Bahrain',        '+973'),
    ('🇴🇲', 'Oman',           '+968'),
    ('🇱🇧', 'Lebanon',        '+961'),
    ('🇮🇶', 'Iraq',           '+964'),
    ('🇲🇦', 'Morocco',        '+212'),
    ('🇹🇳', 'Tunisia',        '+216'),
  ];

  List<(String, String, String)> get _filtered {
    if (_query.isEmpty) return _countries;
    final q = _query.toLowerCase();
    return _countries
        .where((c) => c.$2.toLowerCase().contains(q) || c.$3.contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize:     0.85,
      minChildSize:     0.4,
      expand: false,
      builder: (_, ctrl) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Column(
          children: [
            // Handle
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: context.handleColor,
                borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),

            Text('Select country',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),

            // Search field
            MiskTextField(
              label: 'Search',
              hint:  'Country name or code',
              prefixIcon: const Icon(Icons.search_rounded),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 12),

            // List
            Expanded(
              child: ListView.separated(
                controller: ctrl,
                itemCount:  _filtered.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: context.subtleBg),
                itemBuilder: (_, i) {
                  final (flag, name, code) = _filtered[i];
                  return ListTile(
                    leading: Text(flag, style: const TextStyle(fontSize: 24)),
                    title:   Text(name, style: AppTypography.bodyMedium),
                    trailing: Text(code,
                      style: AppTypography.labelMedium.copyWith(
                        color: context.mutedText)),
                    onTap: () => widget.onSelect(code, flag),
                    contentPadding: EdgeInsets.zero,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ERROR BANNER
// ─────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        context.errorLightBg,
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
              style: AppTypography.bodySmall.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
