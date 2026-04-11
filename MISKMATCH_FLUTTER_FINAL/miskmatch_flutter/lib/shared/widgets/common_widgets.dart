import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';

// ═══════════════════════════════════════════════════════════════════
// MISK BUTTON — primary action button
// ═══════════════════════════════════════════════════════════════════

enum MiskButtonVariant { primary, gold, outline, ghost, dark }

class MiskButton extends StatefulWidget {
  const MiskButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant   = MiskButtonVariant.primary,
    this.loading   = false,
    this.icon,
    this.fullWidth = true,
    this.small     = false,
  });

  final String            label;
  final VoidCallback?     onPressed;
  final MiskButtonVariant variant;
  final bool              loading;
  final IconData?         icon;
  final bool              fullWidth;
  final bool              small;

  @override
  State<MiskButton> createState() => _MiskButtonState();
}

class _MiskButtonState extends State<MiskButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  bool get _disabled => widget.loading || widget.onPressed == null;

  @override
  Widget build(BuildContext context) {
    final h = widget.small ? 44.0 : 56.0;

    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTapDown:   _disabled ? null : (_) => _ctrl.forward(),
        onTapUp:     _disabled ? null : (_) { _ctrl.reverse(); widget.onPressed?.call(); },
        onTapCancel: _disabled ? null : () => _ctrl.reverse(),
        child: AnimatedOpacity(
          opacity:  _disabled && !widget.loading ? 0.45 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width:  widget.fullWidth ? double.infinity : null,
            height: h,
            padding: EdgeInsets.symmetric(horizontal: widget.small ? 16 : 24),
            decoration: _decoration(),
            child: Center(child: _content()),
          ),
        ),
      ),
    );
  }

  BoxDecoration _decoration() {
    switch (widget.variant) {
      case MiskButtonVariant.primary:
        return BoxDecoration(
          gradient:     AppColors.roseGradient,
          borderRadius: AppRadius.buttonRadius,
          boxShadow:    _disabled ? null : [
            BoxShadow(
              color:      AppColors.roseDeep.withOpacity(0.25),
              blurRadius: 20,
              offset:     const Offset(0, 4),
            ),
          ],
        );
      case MiskButtonVariant.gold:
        return BoxDecoration(
          gradient:     AppColors.goldGradient,
          borderRadius: AppRadius.buttonRadius,
          boxShadow:    _disabled ? null : AppShadows.gold,
        );
      case MiskButtonVariant.outline:
        return BoxDecoration(
          color:        Colors.transparent,
          borderRadius: AppRadius.buttonRadius,
          border:       Border.all(
            color: Theme.of(context).colorScheme.primary, width: 1.5),
        );
      case MiskButtonVariant.ghost:
        return BoxDecoration(
          color:        Colors.transparent,
          borderRadius: AppRadius.buttonRadius,
        );
      case MiskButtonVariant.dark:
        return BoxDecoration(
          gradient:     AppColors.nightGradient,
          borderRadius: AppRadius.buttonRadius,
        );
    }
  }

  Color get _fg {
    final primary = Theme.of(context).colorScheme.primary;
    return switch (widget.variant) {
      MiskButtonVariant.primary => AppColors.white,
      MiskButtonVariant.gold    => AppColors.midnightDeep,
      MiskButtonVariant.outline => primary,
      MiskButtonVariant.ghost   => primary,
      MiskButtonVariant.dark    => AppColors.white,
    };
  }

  Widget _content() {
    if (widget.loading) {
      return SizedBox(
        width: 20, height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: _fg),
      );
    }
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.icon != null) ...[
          _maybeFlipIcon(widget.icon!, widget.small ? 18 : 20, isRtl),
          const SizedBox(width: 8),
        ],
        Text(widget.label,
          style: AppTypography.labelLarge.copyWith(
            fontSize: widget.small ? 13 : 15,
            color: _fg,
          ),
        ),
      ],
    );
  }

  /// Directional icons (forward arrows) need to be flipped in RTL mode
  /// because MiskButton receives IconData, bypassing Flutter's auto-mirror.
  static const _rtlFlippableIcons = <IconData>{
    Icons.arrow_forward_rounded,
    Icons.arrow_forward,
    Icons.arrow_forward_ios_rounded,
    Icons.arrow_forward_ios,
  };

  Widget _maybeFlipIcon(IconData icon, double size, bool isRtl) {
    final child = Icon(icon, size: size, color: _fg);
    if (isRtl && _rtlFlippableIcons.contains(icon)) {
      return Transform.flip(flipX: true, child: child);
    }
    return child;
  }
}

// ═══════════════════════════════════════════════════════════════════
// MISK TEXT FIELD
// ═══════════════════════════════════════════════════════════════════

class MiskTextField extends StatelessWidget {
  const MiskTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.initialValue,
    this.keyboardType,
    this.obscureText    = false,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.maxLines       = 1,
    this.maxLength,
    this.enabled        = true,
    this.autofocus      = false,
    this.textInputAction,
    this.readOnly       = false,
    this.onTap,
  }) : assert(controller == null || initialValue == null,
         'Cannot provide both controller and initialValue');

  final String                label;
  final String?               hint;
  final TextEditingController? controller;
  final String?               initialValue;
  final TextInputType?        keyboardType;
  final bool                  obscureText;
  final Widget?               prefixIcon;
  final Widget?               suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final int                   maxLines;
  final int?                  maxLength;
  final bool                  enabled;
  final bool                  autofocus;
  final TextInputAction?      textInputAction;
  final bool                  readOnly;
  final VoidCallback?         onTap;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:       controller,
      initialValue:     controller == null ? initialValue : null,
      keyboardType:     keyboardType,
      obscureText:      obscureText,
      validator:        validator,
      onChanged:        onChanged,
      onFieldSubmitted: onSubmitted,
      maxLines:         obscureText ? 1 : maxLines,
      maxLength:        maxLength,
      enabled:          enabled,
      autofocus:        autofocus,
      textInputAction:  textInputAction,
      readOnly:         readOnly,
      onTap:            onTap,
      style: AppTypography.bodyLarge.copyWith(
        color: context.onSurface,
      ),
      decoration: InputDecoration(
        labelText:   label,
        hintText:    hint,
        prefixIcon:  prefixIcon != null
            ? Padding(
                padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.roseDeep.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: IconTheme(
                    data: const IconThemeData(
                      size: 18, color: AppColors.roseDeep),
                    child: prefixIcon!,
                  ),
                ),
              )
            : null,
        suffixIcon:  suffixIcon,
        counterText: '',
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// MISK CARD
// ═══════════════════════════════════════════════════════════════════

class MiskCard extends StatelessWidget {
  const MiskCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.color,
    this.selected = false,
  });

  final Widget              child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback?       onTap;
  final Color?              color;
  final bool                selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color:        color ?? context.cardSurface,
        borderRadius: AppRadius.cardRadius,
        boxShadow:    context.cardShadow,
        border: Border.all(
          color: selected ? AppColors.roseDeep : context.cardBorder,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Material(
        color:        Colors.transparent,
        borderRadius: AppRadius.cardRadius,
        child: InkWell(
          onTap:        onTap,
          borderRadius: AppRadius.cardRadius,
          child: Padding(
            padding: padding ?? const EdgeInsets.all(AppSpacing.cardPadding),
            child:   child,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// COMPATIBILITY RING — dual-ring circular progress
// ═══════════════════════════════════════════════════════════════════

class CompatibilityRing extends StatefulWidget {
  const CompatibilityRing({
    super.key,
    required this.score,
    this.size      = 72,
    this.showLabel = true,
  });

  final double score;
  final double size;
  final bool   showLabel;

  @override
  State<CompatibilityRing> createState() => _CompatibilityRingState();
}

class _CompatibilityRingState extends State<CompatibilityRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _progress;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800));
    _progress = Tween(begin: 0.0, end: widget.score / 100).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(CompatibilityRing old) {
    super.didUpdateWidget(old);
    if (old.score != widget.score) {
      _progress = Tween(begin: _progress.value, end: widget.score / 100)
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Color get _color {
    if (widget.score >= 85) return AppColors.goldPrimary;
    if (widget.score >= 72) return AppColors.success;
    if (widget.score >= 58) return AppColors.roseDeep;
    return AppColors.neutral500;
  }

  String get _tier {
    if (widget.score >= 85) return 'Exceptional';
    if (widget.score >= 72) return 'Strong';
    if (widget.score >= 58) return 'Good';
    return 'Moderate';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Compatibility score ${widget.score.round()} percent, $_tier',
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _progress,
        builder: (_, __) => SizedBox(
          width: widget.size, height: widget.size,
          child: CustomPaint(
            painter: _RingPainter(
              progress:   _progress.value,
              outerColor: AppColors.roseDeep,
              innerColor: AppColors.goldPrimary,
              outerWidth: 5,
              innerWidth: 3,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${widget.score.round()}%',
                    style: TextStyle(
                      fontFamily:  'Georgia',
                      fontSize:    widget.size * 0.22,
                      fontWeight:  FontWeight.w700,
                      color:       _color,
                    ),
                  ),
                  if (widget.showLabel)
                    Text(_tier,
                      style: AppTypography.caption.copyWith(
                        fontSize: widget.size * 0.10,
                        color:    _color,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.outerColor,
    required this.innerColor,
    required this.outerWidth,
    required this.innerWidth,
  });

  final double progress;
  final Color  outerColor, innerColor;
  final double outerWidth, innerWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.width / 2 - outerWidth / 2;
    final innerR = outerR - outerWidth / 2 - innerWidth / 2 - 2;
    const startAngle = -math.pi / 2;

    // Outer track
    canvas.drawCircle(center, outerR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = outerWidth
        ..color = outerColor.withOpacity(0.12));

    // Outer progress
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: outerR),
      startAngle, progress * 2 * math.pi, false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = outerWidth
        ..strokeCap = StrokeCap.round
        ..color = outerColor);

    // Inner track
    canvas.drawCircle(center, innerR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = innerWidth
        ..color = innerColor.withOpacity(0.12));

    // Inner progress (gold, slightly behind outer)
    final innerProgress = (progress * 0.85).clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: innerR),
      startAngle, innerProgress * 2 * math.pi, false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = innerWidth
        ..strokeCap = StrokeCap.round
        ..color = innerColor);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// ═══════════════════════════════════════════════════════════════════
// TRUST BADGE — pill-shaped verification indicator
// ═══════════════════════════════════════════════════════════════════

enum TrustBadgeType { mosque, scholar, identity }

class TrustBadge extends StatelessWidget {
  const TrustBadge({super.key, required this.type});

  final TrustBadgeType type;

  String get _semanticsLabel => switch (type) {
    TrustBadgeType.mosque   => 'Mosque verified',
    TrustBadgeType.scholar  => 'Scholar endorsed',
    TrustBadgeType.identity => 'ID verified',
  };

  @override
  Widget build(BuildContext context) {
    final (icon, label, bg) = switch (type) {
      TrustBadgeType.mosque   => (Icons.shield_rounded,  'Verified',    AppColors.goldPrimary),
      TrustBadgeType.scholar  => (Icons.star_rounded,    'Endorsed',    AppColors.roseDeep),
      TrustBadgeType.identity => (Icons.check_rounded,   'ID Verified', AppColors.success),
    };

    return Semantics(
      label: _semanticsLabel,
      excludeSemantics: true,
      child: Container(
        height:  22,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color:        bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: AppColors.white),
            const SizedBox(width: 4),
            Text(label,
              style: const TextStyle(
                fontSize:   9,
                fontWeight: FontWeight.w600,
                color:      AppColors.white,
                height:     1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ARABIC TEXT — always RTL, Scheherazade, goldPrimary default
// ═══════════════════════════════════════════════════════════════════

class ArabicText extends StatelessWidget {
  const ArabicText(this.text, {super.key, this.style, this.textAlign});

  final String     text;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Text(
        text,
        style: style ?? AppTypography.arabicBody,
        textAlign: textAlign ?? TextAlign.right,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SECTION HEADER — title + optional Arabic subtitle + rose accent
// ═══════════════════════════════════════════════════════════════════

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.arabicSubtitle,
  });

  final String  title;
  final String? arabicSubtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 2,
                decoration: BoxDecoration(
                  color:        AppColors.roseDeep,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                  style: AppTypography.titleMedium.copyWith(
                    fontSize: 18, fontWeight: FontWeight.w700,
                    color: context.onSurface,
                  ),
                ),
              ),
              if (arabicSubtitle != null)
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(arabicSubtitle!,
                    style: const TextStyle(
                      fontFamily: 'Scheherazade',
                      fontSize:   14,
                      color:      AppColors.goldPrimary,
                      height:     2.0,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Divider(height: 1, color: context.subtleBg),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// LOADING OVERLAY
// ═══════════════════════════════════════════════════════════════════

class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
  });

  final bool   isLoading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black.withOpacity(0.35),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color:        Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  boxShadow:    context.isDark ? [] : AppShadows.elevated,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: AppColors.roseDeep, strokeWidth: 3),
                    const SizedBox(height: 16),
                    Text(
                      'يُسِّر اللهُ أمرنا',
                      style: AppTypography.arabicBody,
                    ),
                  ],
                ),
              ),
            ),
          ).animate().fadeIn(duration: 200.ms),
      ],
    );
  }
}
