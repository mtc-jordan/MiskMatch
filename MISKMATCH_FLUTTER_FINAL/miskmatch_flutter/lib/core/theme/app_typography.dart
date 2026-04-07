import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// MiskMatch Typography
///
/// Latin: Inter (clean, modern, excellent Arabic complement)
/// Arabic: Scheherazade New (traditional, authoritative, beautiful)
///
/// Scale follows Material 3 type scale with Islamic design sensibilities.

abstract class AppTypography {
  // ── Font families ────────────────────────────────────────────────────────
  static String get _latin => GoogleFonts.inter().fontFamily!;
  static const String _arabic = 'Scheherazade';

  /// Pick correct font based on text direction in context
  static String fontFamily(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return isRtl ? _arabic : _latin;
  }

  // ── Display ──────────────────────────────────────────────────────────────
  static TextStyle get displayLarge => GoogleFonts.inter(
    fontSize: 57,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.25,
    color: AppColors.neutral900,
    height: 1.12,
  );

  static TextStyle get displayMedium => GoogleFonts.inter(
    fontSize: 45,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    color: AppColors.neutral900,
    height: 1.16,
  );

  // ── Headlines ────────────────────────────────────────────────────────────
  static TextStyle get headlineLarge => GoogleFonts.inter(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: AppColors.neutral900,
    height: 1.25,
  );

  static TextStyle get headlineMedium => GoogleFonts.inter(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: AppColors.neutral900,
    height: 1.29,
  );

  static TextStyle get headlineSmall => GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: AppColors.neutral900,
    height: 1.33,
  );

  // ── Titles ───────────────────────────────────────────────────────────────
  static TextStyle get titleLarge => GoogleFonts.inter(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: AppColors.neutral900,
    height: 1.27,
  );

  static TextStyle get titleMedium => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    color: AppColors.neutral900,
    height: 1.50,
  );

  static TextStyle get titleSmall => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    color: AppColors.neutral900,
    height: 1.43,
  );

  // ── Body ─────────────────────────────────────────────────────────────────
  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
    color: AppColors.neutral700,
    height: 1.50,
  );

  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    color: AppColors.neutral700,
    height: 1.43,
  );

  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    color: AppColors.neutral500,
    height: 1.33,
  );

  // ── Labels ───────────────────────────────────────────────────────────────
  static TextStyle get labelLarge => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    color: AppColors.neutral900,
    height: 1.43,
  );

  static TextStyle get labelMedium => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: AppColors.neutral700,
    height: 1.33,
  );

  static TextStyle get labelSmall => GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: AppColors.neutral500,
    height: 1.45,
  );

  // ── Islamic / Arabic styles ───────────────────────────────────────────────
  /// Used for Quranic ayahs, Arabic names, bismillah
  static TextStyle get arabicDisplay => const TextStyle(
    fontFamily: _arabic,
    fontSize: 32,
    fontWeight: FontWeight.w400,
    color: AppColors.roseDeep,
    height: 1.8,   // Arabic needs more line height
  );

  static TextStyle get arabicTitle => const TextStyle(
    fontFamily: _arabic,
    fontSize: 22,
    fontWeight: FontWeight.w400,
    color: AppColors.neutral900,
    height: 1.8,
  );

  static TextStyle get arabicBody => const TextStyle(
    fontFamily: _arabic,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.neutral700,
    height: 1.8,
  );

  /// App tagline — "ختامه مسك"
  static TextStyle get taglineStyle => const TextStyle(
    fontFamily: _arabic,
    fontSize: 18,
    fontWeight: FontWeight.w400,
    color: AppColors.goldPrimary,
    height: 2.0,
    letterSpacing: 1.5,
  );

  // ── Compatibility score display ───────────────────────────────────────────
  static TextStyle get scoreDisplay => GoogleFonts.inter(
    fontSize: 48,
    fontWeight: FontWeight.w700,
    letterSpacing: -1,
    color: AppColors.roseDeep,
    height: 1.0,
  );

  // ── OTP digits ────────────────────────────────────────────────────────────
  static TextStyle get otpDigit => GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: 2,
    color: AppColors.neutral900,
  );
}
