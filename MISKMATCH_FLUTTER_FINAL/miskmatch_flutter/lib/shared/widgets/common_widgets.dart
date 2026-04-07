import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';

// ═══════════════════════════════════════════════════════════════════
// MISK BUTTON — primary CTA
// ═══════════════════════════════════════════════════════════════════

enum MiskButtonVariant { primary, secondary, outline, ghost, gold }

class MiskButton extends StatelessWidget {
  const MiskButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant    = MiskButtonVariant.primary,
    this.loading    = false,
    this.icon,
    this.fullWidth  = true,
    this.small      = false,
  });

  final String           label;
  final VoidCallback?    onPressed;
  final MiskButtonVariant variant;
  final bool             loading;
  final IconData?        icon;
  final bool             fullWidth;
  final bool             small;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final h     = small ? 44.0 : 56.0;

    final child = loading
        ? SizedBox(
            width:  20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _fgColor(theme),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: small ? 18 : 20),
                const SizedBox(width: 8),
              ],
              Text(label,
                  style: AppTypography.labelLarge.copyWith(
                    fontSize: small ? 14 : 16,
                    color:    _fgColor(theme),
                  )),
            ],
          );

    return SizedBox(
      width:  fullWidth ? double.infinity : null,
      height: h,
      child: _buildButton(context, theme, child),
    );
  }

  Widget _buildButton(BuildContext context, ThemeData theme, Widget child) {
    switch (variant) {
      case MiskButtonVariant.primary:
        return ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.buttonRadius,
            ),
            minimumSize: Size(double.infinity, small ? 44 : 56),
          ),
          child: child,
        );

      case MiskButtonVariant.gold:
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppColors.goldGradient,
            borderRadius: AppRadius.buttonRadius,
            boxShadow: [
              BoxShadow(
                color:      AppColors.goldPrimary.withOpacity(0.3),
                blurRadius: 12,
                offset:     const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: loading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: AppColors.white,
              shadowColor:     Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.buttonRadius,
              ),
              minimumSize: Size(double.infinity, small ? 44 : 56),
            ),
            child: child,
          ),
        );

      case MiskButtonVariant.secondary:
        return ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primaryContainer,
            foregroundColor: theme.colorScheme.primary,
            elevation:       0,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.buttonRadius,
            ),
            minimumSize: Size(double.infinity, small ? 44 : 56),
          ),
          child: child,
        );

      case MiskButtonVariant.outline:
        return OutlinedButton(
          onPressed: loading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.primary,
            side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.buttonRadius,
            ),
            minimumSize: Size(double.infinity, small ? 44 : 56),
          ),
          child: child,
        );

      case MiskButtonVariant.ghost:
        return TextButton(
          onPressed: loading ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.buttonRadius,
            ),
            minimumSize: Size(double.infinity, small ? 44 : 56),
          ),
          child: child,
        );
    }
  }

  Color _fgColor(ThemeData theme) {
    return switch (variant) {
      MiskButtonVariant.primary   => theme.colorScheme.onPrimary,
      MiskButtonVariant.gold      => AppColors.white,
      MiskButtonVariant.secondary => theme.colorScheme.primary,
      MiskButtonVariant.outline   => theme.colorScheme.primary,
      MiskButtonVariant.ghost     => theme.colorScheme.primary,
    };
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
  });

  final String               label;
  final String?              hint;
  final TextEditingController? controller;
  final TextInputType?       keyboardType;
  final bool                 obscureText;
  final Widget?              prefixIcon;
  final Widget?              suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final int                  maxLines;
  final int?                 maxLength;
  final bool                 enabled;
  final bool                 autofocus;
  final TextInputAction?     textInputAction;
  final bool                 readOnly;
  final VoidCallback?        onTap;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:      controller,
      keyboardType:    keyboardType,
      obscureText:     obscureText,
      validator:       validator,
      onChanged:       onChanged,
      onFieldSubmitted: onSubmitted,
      maxLines:        obscureText ? 1 : maxLines,
      maxLength:       maxLength,
      enabled:         enabled,
      autofocus:       autofocus,
      textInputAction: textInputAction,
      readOnly:        readOnly,
      onTap:           onTap,
      style:           AppTypography.bodyLarge.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        labelText:  label,
        hintText:   hint,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        counterText: '',
      ),
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
            child: const Center(
              child: _MiskLoader(),
            ),
          ).animate().fadeIn(duration: 200.ms),
      ],
    );
  }
}

class _MiskLoader extends StatelessWidget {
  const _MiskLoader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color:        Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow:    AppShadows.elevated,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color:       Theme.of(context).colorScheme.primary,
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'يُسِّر اللهُ أمرنا',
            style: AppTypography.arabicBody.copyWith(
              color: AppColors.goldPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ARABIC TEXT WIDGET — renders Arabic with correct font + RTL
// ═══════════════════════════════════════════════════════════════════

class ArabicText extends StatelessWidget {
  const ArabicText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
  });

  final String     text;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Text(
        text,
        style:     style ?? AppTypography.arabicBody,
        textAlign: textAlign ?? TextAlign.right,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TRUST BADGE — mosque / scholar verified indicator
// ═══════════════════════════════════════════════════════════════════

class TrustBadge extends StatelessWidget {
  const TrustBadge({
    super.key,
    required this.type,
  });

  final TrustBadgeType type;

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (type) {
      TrustBadgeType.mosque   => (Icons.mosque_rounded,   'Mosque Verified',   AppColors.roseDeep),
      TrustBadgeType.scholar  => (Icons.star_rounded,     'Scholar Endorsed',  AppColors.goldPrimary),
      TrustBadgeType.identity => (Icons.verified_rounded, 'ID Verified',       AppColors.success),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.1),
        borderRadius: AppRadius.chipRadius,
        border:       Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color:      color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

enum TrustBadgeType { mosque, scholar, identity }

// ═══════════════════════════════════════════════════════════════════
// COMPATIBILITY SCORE RING
// ═══════════════════════════════════════════════════════════════════

class CompatibilityRing extends StatelessWidget {
  const CompatibilityRing({
    super.key,
    required this.score,
    this.size   = 72,
    this.showLabel = true,
  });

  final double score;
  final double size;
  final bool   showLabel;

  Color get _color {
    if (score >= 85) return AppColors.compatExceptional;
    if (score >= 72) return AppColors.compatStrong;
    if (score >= 58) return AppColors.compatGood;
    if (score >= 42) return AppColors.compatModerate;
    return AppColors.compatLow;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width:  size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ring
          CircularProgressIndicator(
            value:       1.0,
            strokeWidth: size * 0.08,
            color:       _color.withOpacity(0.15),
          ),
          // Score ring
          CircularProgressIndicator(
            value:       score / 100,
            strokeWidth: size * 0.08,
            color:       _color,
            strokeCap:   StrokeCap.round,
          ),
          // Score text
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${score.round()}',
                style: AppTypography.titleMedium.copyWith(
                  color:      _color,
                  fontSize:   size * 0.25,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (showLabel)
                Text(
                  '%',
                  style: AppTypography.labelSmall.copyWith(
                    color:    _color,
                    fontSize: size * 0.14,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// MISK CARD — standard card container
// ═══════════════════════════════════════════════════════════════════

class MiskCard extends StatelessWidget {
  const MiskCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.color,
  });

  final Widget  child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback?       onTap;
  final Color?              color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin:     margin,
      decoration: BoxDecoration(
        color:        color ?? theme.colorScheme.surface,
        borderRadius: AppRadius.cardRadius,
        boxShadow:    AppShadows.card,
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
          width: 1,
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
