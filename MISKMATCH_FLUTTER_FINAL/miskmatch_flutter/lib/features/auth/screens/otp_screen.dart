import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  final List<TextEditingController> _ctrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes =
      List.generate(6, (_) => FocusNode());

  int    _resendSeconds = 60;
  Timer? _timer;
  bool   _canResend     = false;
  bool   _shakeError    = false;
  bool   _successFlash  = false;

  String get _otp => _ctrls.map((c) => c.text).join();

  String get _maskedPhone {
    final p = widget.phone;
    if (p.length < 6) return p;
    return '${p.substring(0, p.length - 4).replaceRange(
        (p.length - 4 - 3).clamp(0, p.length), p.length - 4, '•••')}${p.substring(p.length - 2)}';
  }

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nodes[0].requestFocus();
    });
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() { _resendSeconds = 60; _canResend = false; });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendSeconds <= 1) {
        t.cancel();
        if (mounted) setState(() => _canResend = true);
      } else {
        if (mounted) setState(() => _resendSeconds--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final n in _nodes) { n.dispose(); }
    // Controllers not disposed — PinCode accesses after dispose
    super.dispose();
  }

  Future<void> _verify() async {
    if (_otp.length < 6) return;
    HapticFeedback.mediumImpact();
    await ref.read(authProvider.notifier).verifyOtp(
      phone:     widget.phone,
      otp:       _otp,
      isNewUser: widget.isNewUser,
    );
  }

  Future<void> _resend() async {
    if (!_canResend) return;
    for (final c in _ctrls) { c.clear(); }
    _nodes[0].requestFocus();
    await ref.read(authProvider.notifier).resendOtp(widget.phone);
    _startTimer();
  }

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _nodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _nodes[index - 1].requestFocus();
    }
    setState(() {});
    if (_otp.length == 6) {
      _verify();
    }
  }

  void _triggerShake() {
    setState(() => _shakeError = true);
    HapticFeedback.heavyImpact();
    Future.delayed(500.ms, () {
      if (mounted) setState(() => _shakeError = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth      = ref.watch(authProvider);
    final isLoading = auth is AuthLoading;
    final error     = auth is AuthError ? auth.error : null;
    final mq        = MediaQuery.of(context);

    // Shake on error
    ref.listen(authProvider, (prev, next) {
      if (next is AuthError) _triggerShake();
    });

    return LoadingOverlay(
      isLoading: isLoading,
      child: Scaffold(
        backgroundColor: context.scaffoldColor,
        body: SingleChildScrollView(
          child: Column(
            children: [
              // ── Gradient header (30%) ───────────────────────────────────
              _OtpHeader(
                height:      mq.size.height * 0.30,
                maskedPhone: _maskedPhone,
                onBack:      () => Navigator.of(context).pop(),
              ),

              // ── Content ─────────────────────────────────────────────────
              Transform.translate(
                offset: const Offset(0, -28),
                child: Container(
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
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                    child: Column(
                      children: [
                        Text('Enter verification code',
                          style: AppTypography.titleLarge.copyWith(
                            fontSize: 20, fontWeight: FontWeight.w700,
                            color: context.onSurface),
                        ),
                        const SizedBox(height: 6),
                        Text('6-digit code sent to your phone',
                          style: AppTypography.bodySmall.copyWith(
                            fontSize: 13, color: context.mutedText),
                        ),

                        const SizedBox(height: 32),

                        // ── OTP boxes ──────────────────────────────────
                        _OtpBoxes(
                          controllers: _ctrls,
                          focusNodes:  _nodes,
                          onChanged:   _onDigitChanged,
                          shakeError:  _shakeError,
                          successFlash: _successFlash,
                        ),

                        const SizedBox(height: 20),

                        // Error
                        if (error != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:        context.errorLightBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.error.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: AppColors.error, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(error.message,
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.error)),
                                ),
                              ],
                            ),
                          )
                              .animate()
                              .fadeIn(duration: 300.ms)
                              .shakeX(amount: 4),

                        const SizedBox(height: 24),

                        // Verify button — only when 6 digits
                        if (_otp.length == 6)
                          MiskButton(
                            label:     'Verify & continue',
                            onPressed: _verify,
                            loading:   isLoading,
                            icon:      Icons.check_circle_outline_rounded,
                          )
                              .animate()
                              .fadeIn(duration: 300.ms)
                              .slideY(begin: 0.15, end: 0,
                                      duration: 300.ms,
                                      curve: Curves.easeOutBack),

                        if (_otp.length < 6)
                          const SizedBox(height: 56), // placeholder height

                        const SizedBox(height: 24),

                        // Countdown / resend
                        _canResend
                            ? MiskButton(
                                label:     'Resend code',
                                onPressed: _resend,
                                variant:   MiskButtonVariant.ghost,
                                fullWidth: false,
                                small:     true,
                                icon:      Icons.refresh_rounded,
                              )
                            : Text(
                                'Resend in 0:${_resendSeconds.toString().padLeft(2, '0')}',
                                style: AppTypography.bodySmall.copyWith(
                                  color: _resendSeconds <= 10
                                      ? AppColors.roseDeep
                                      : context.mutedText,
                                  fontSize: 12,
                                ),
                              ),

                        const SizedBox(height: 32),

                        // Security note
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('🔒 ',
                              style: TextStyle(fontSize: 12)),
                            Text(
                              'Your OTP is private. We will never ask for it.',
                              style: AppTypography.caption.copyWith(
                                color: context.mutedText,
                                fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 100.ms)
                  .slideY(begin: 0.06, end: 0,
                          duration: 400.ms, curve: Curves.easeOutCubic),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// GRADIENT HEADER
// ─────────────────────────────────────────────

class _OtpHeader extends StatelessWidget {
  const _OtpHeader({
    required this.height,
    required this.maskedPhone,
    required this.onBack,
  });

  final double      height;
  final String      maskedPhone;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
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
          padding: const EdgeInsets.fromLTRB(8, 0, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded,
                    color: AppColors.white),
              ),

              const Spacer(),

              Padding(
                padding: const EdgeInsetsDirectional.only(start: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Verify your\nnumber',
                      style: TextStyle(
                        fontFamily: 'Georgia', fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white, height: 1.2,
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 500.ms)
                        .slideY(begin: 0.1, end: 0, duration: 500.ms,
                                curve: Curves.easeOutCubic),

                    const SizedBox(height: 10),

                    GestureDetector(
                      onTap: onBack,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(maskedPhone,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.neutral300, fontSize: 14),
                          ),
                          const SizedBox(width: 8),
                          Text('Change',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.goldLight,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.goldLight),
                          ),
                        ],
                      ),
                    )
                        .animate(delay: 200.ms)
                        .fadeIn(duration: 400.ms),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// OTP INPUT BOXES
// ─────────────────────────────────────────────

class _OtpBoxes extends StatelessWidget {
  const _OtpBoxes({
    required this.controllers,
    required this.focusNodes,
    required this.onChanged,
    required this.shakeError,
    required this.successFlash,
  });

  final List<TextEditingController> controllers;
  final List<FocusNode>             focusNodes;
  final void Function(int, String)  onChanged;
  final bool                        shakeError;
  final bool                        successFlash;

  @override
  Widget build(BuildContext context) {
    Widget row = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (i) {
        final hasValue = controllers[i].text.isNotEmpty;
        final isFocused = focusNodes[i].hasFocus;

        return Container(
          width: 52, height: 60,
          margin: EdgeInsets.only(
            left: i == 0 ? 0 : 6,
            right: i == 5 ? 0 : 6,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: hasValue
                  ? AppColors.roseLight.withOpacity(0.5)
                  : context.surfaceColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasValue
                    ? AppColors.roseDeep
                    : isFocused
                        ? AppColors.roseDeep
                        : context.isDark ? AppColors.neutral700 : AppColors.neutral300,
                width: (hasValue || isFocused) ? 2 : 1,
              ),
              boxShadow: isFocused
                  ? [
                      BoxShadow(
                        color: AppColors.roseDeep.withOpacity(0.15),
                        blurRadius: 12, spreadRadius: 1),
                    ]
                  : null,
            ),
            child: Center(
              child: TextField(
                controller:    controllers[i],
                focusNode:     focusNodes[i],
                keyboardType:  TextInputType.number,
                textAlign:     TextAlign.center,
                maxLength:     1,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontSize:   24,
                  fontWeight: FontWeight.w700,
                  color:      AppColors.roseDeep,
                ),
                decoration: const InputDecoration(
                  counterText: '',
                  border:      InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                onChanged: (v) => onChanged(i, v),
              ),
            ),
          ),
        )
            .animate(delay: (i * 60).ms)
            .fadeIn(duration: 300.ms)
            .slideY(begin: 0.1, end: 0, duration: 300.ms,
                    curve: Curves.easeOutCubic);
      }),
    );

    if (shakeError) {
      row = row
          .animate(onPlay: (c) => c.forward())
          .shakeX(amount: 6, duration: 400.ms);
    }

    return row;
  }
}
