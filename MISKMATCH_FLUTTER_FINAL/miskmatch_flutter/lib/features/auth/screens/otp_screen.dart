import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/shared/widgets/common_widgets.dart';
import '../providers/auth_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({
    super.key,
    required this.phone,
    required this.isNewUser,
  });

  final String phone;
  final bool   isNewUser;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otpCtrl       = TextEditingController();
  String _otp          = '';
  int    _resendSeconds = 60;
  Timer? _timer;
  bool   _canResend    = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    setState(() {
      _resendSeconds = 60;
      _canResend     = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendSeconds <= 1) {
        t.cancel();
        setState(() => _canResend = true);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    // Note: _otpCtrl is intentionally NOT disposed here.
    // PinCodeTextField internally accesses the controller during widget tree
    // teardown, and disposing it prematurely causes "used after disposed" errors.
    // The controller will be garbage-collected with this State object.
    super.dispose();
  }

  Future<void> _verify() async {
    if (_otp.length < 6) return;
    await ref.read(authProvider.notifier).verifyOtp(
      phone:     widget.phone,
      otp:       _otp,
      isNewUser: widget.isNewUser,
    );
  }

  Future<void> _resend() async {
    if (!_canResend) return;
    _otpCtrl.clear();
    setState(() => _otp = '');
    await ref.read(authProvider.notifier).resendOtp(widget.phone);
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    final auth      = ref.watch(authProvider);
    final isLoading = auth is AuthLoading;
    final error     = auth is AuthError ? auth.error : null;
    final theme     = Theme.of(context);

    return LoadingOverlay(
      isLoading: isLoading,
      child: Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),

                // Icon
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    gradient: AppColors.roseGradient,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.sms_outlined,
                      color: AppColors.white, size: 36),
                )
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .scale(begin: const Offset(0.8, 0.8)),

                const SizedBox(height: 28),

                Text('Verify your number',
                    style: AppTypography.headlineSmall.copyWith(
                      color: AppColors.neutral900,
                    ))
                    .animate(delay: 100.ms)
                    .fadeIn(duration: 400.ms),

                const SizedBox(height: 8),

                Text(
                  'Enter the 6-digit code sent to\n${widget.phone}',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.neutral500,
                  ),
                )
                    .animate(delay: 150.ms)
                    .fadeIn(duration: 400.ms),

                const SizedBox(height: 36),

                // ── OTP input ───────────────────────────────────────────
                PinCodeTextField(
                  appContext:   context,
                  length:       6,
                  controller:   _otpCtrl,
                  keyboardType: TextInputType.number,
                  animationType: AnimationType.scale,
                  autoFocus:    true,
                  pinTheme: PinTheme(
                    shape:              PinCodeFieldShape.box,
                    borderRadius:       BorderRadius.circular(14),
                    fieldHeight:        58,
                    fieldWidth:         50,
                    activeFillColor:    theme.colorScheme.surface,
                    inactiveFillColor:  theme.colorScheme.surface,
                    selectedFillColor:  theme.colorScheme.primaryContainer,
                    activeColor:        theme.colorScheme.primary,
                    inactiveColor:      theme.colorScheme.outline,
                    selectedColor:      theme.colorScheme.primary,
                    borderWidth:        2,
                  ),
                  textStyle: AppTypography.otpDigit.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                  enableActiveFill: true,
                  onChanged:  (v) => setState(() => _otp = v),
                  onCompleted: (_) => _verify(),
                )
                    .animate(delay: 200.ms)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.1, end: 0),

                const SizedBox(height: 16),

                // Error
                if (error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:        AppColors.errorLight,
                      borderRadius: BorderRadius.circular(12),
                      border:       Border.all(
                        color: AppColors.error.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(error.message,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.error,
                              )),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn()
                      .shakeX(amount: 4),

                const SizedBox(height: 28),

                // Verify button
                MiskButton(
                  label:     'Verify & continue',
                  onPressed: _otp.length == 6 ? _verify : null,
                  loading:   isLoading,
                  icon:      Icons.check_circle_outline_rounded,
                )
                    .animate(delay: 300.ms)
                    .fadeIn(duration: 400.ms),

                const SizedBox(height: 24),

                // Resend
                _canResend
                    ? TextButton.icon(
                        onPressed: _resend,
                        icon:      const Icon(Icons.refresh_rounded, size: 18),
                        label:     const Text('Resend code'),
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.primary,
                        ),
                      )
                    : Text(
                        'Resend in $_resendSeconds seconds',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.neutral500,
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
