import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// MiskMatch Typography
///
/// Display/Headline: Georgia — warm, editorial, premium
/// Arabic:           Scheherazade New — traditional, beautiful
/// Body/Labels:      Inter — clean, modern, highly legible

abstract class AppTypography {
  static const String _arabic = 'Scheherazade';

  // ── Display (Georgia, 36-48pt, bold) ─────────────────────────────────────
  static const displayLarge = TextStyle(
    fontFamily:    'Georgia',
    fontSize:      48,
    fontWeight:    FontWeight.w700,
    color:         AppColors.roseDeep,
    height:        1.12,
  );

  static const displayMedium = TextStyle(
    fontFamily:    'Georgia',
    fontSize:      36,
    fontWeight:    FontWeight.w700,
    color:         AppColors.roseDeep,
    height:        1.16,
  );

  // ── Headlines (Georgia, 24-32pt, bold) ───────────────────────────────────
  static TextStyle get headlineLarge => const TextStyle(
    fontFamily:    'Georgia',
    fontSize:      32,
    fontWeight:    FontWeight.w700,
    color:         AppColors.neutral900,
    height:        1.25,
  );

  static TextStyle get headlineMedium => const TextStyle(
    fontFamily:    'Georgia',
    fontSize:      28,
    fontWeight:    FontWeight.w700,
    color:         AppColors.neutral900,
    height:        1.29,
  );

  static TextStyle get headlineSmall => const TextStyle(
    fontFamily:    'Georgia',
    fontSize:      24,
    fontWeight:    FontWeight.w700,
    color:         AppColors.neutral900,
    height:        1.33,
  );

  // ── Titles (Inter, 18-20pt, semibold) ────────────────────────────────────
  static TextStyle get titleLarge => GoogleFonts.inter(
    fontSize:      20,
    fontWeight:    FontWeight.w600,
    color:         AppColors.neutral900,
    height:        1.30,
  );

  static TextStyle get titleMedium => GoogleFonts.inter(
    fontSize:      18,
    fontWeight:    FontWeight.w600,
    letterSpacing: 0.15,
    color:         AppColors.neutral900,
    height:        1.40,
  );

  static TextStyle get titleSmall => GoogleFonts.inter(
    fontSize:      16,
    fontWeight:    FontWeight.w600,
    letterSpacing: 0.1,
    color:         AppColors.neutral900,
    height:        1.43,
  );

  // ── Body (Inter, 14-16pt, regular, height 1.6) ──────────────────────────
  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize:      16,
    fontWeight:    FontWeight.w400,
    color:         AppColors.neutral700,
    height:        1.6,
  );

  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize:      14,
    fontWeight:    FontWeight.w400,
    color:         AppColors.neutral700,
    height:        1.6,
  );

  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize:      12,
    fontWeight:    FontWeight.w400,
    color:         AppColors.neutral500,
    height:        1.6,
  );

  // ── Labels (Inter, 10-12pt, medium, letterSpacing 0.5-2.0) ──────────────
  static TextStyle get labelLarge => GoogleFonts.inter(
    fontSize:      15,
    fontWeight:    FontWeight.w700,
    letterSpacing: 0.3,
    color:         AppColors.white,
    height:        1.43,
  );

  static TextStyle get labelMedium => GoogleFonts.inter(
    fontSize:      12,
    fontWeight:    FontWeight.w500,
    letterSpacing: 0.5,
    color:         AppColors.neutral700,
    height:        1.33,
  );

  static TextStyle get labelSmall => GoogleFonts.inter(
    fontSize:      10,
    fontWeight:    FontWeight.w500,
    letterSpacing: 0.5,
    color:         AppColors.neutral500,
    height:        1.45,
  );

  // ── Caption (10pt, neutral500) ───────────────────────────────────────────
  static TextStyle get caption => GoogleFonts.inter(
    fontSize:      10,
    fontWeight:    FontWeight.w400,
    color:         AppColors.neutral500,
    height:        1.4,
  );

  // ── Arabic (Scheherazade New, height 2.0) ────────────────────────────────
  static TextStyle get arabicDisplay => const TextStyle(
    fontFamily:  _arabic,
    fontSize:    32,
    fontWeight:  FontWeight.w400,
    color:       AppColors.goldPrimary,
    height:      2.0,
  );

  static TextStyle get arabicTitle => const TextStyle(
    fontFamily:  _arabic,
    fontSize:    22,
    fontWeight:  FontWeight.w400,
    color:       AppColors.goldPrimary,
    height:      2.0,
  );

  static TextStyle get arabicBody => const TextStyle(
    fontFamily:  _arabic,
    fontSize:    16,
    fontWeight:  FontWeight.w400,
    color:       AppColors.goldPrimary,
    height:      2.0,
  );

  static TextStyle get taglineStyle => const TextStyle(
    fontFamily:    _arabic,
    fontSize:      18,
    fontWeight:    FontWeight.w400,
    color:         AppColors.goldPrimary,
    height:        2.0,
    letterSpacing: 1.5,
  );

  // ── Score display ────────────────────────────────────────────────────────
  static const scoreDisplay = TextStyle(
    fontFamily:    'Georgia',
    fontSize:      48,
    fontWeight:    FontWeight.w700,
    letterSpacing: -1,
    color:         AppColors.roseDeep,
    height:        1.0,
  );

  // ── OTP digits ───────────────────────────────────────────────────────────
  static TextStyle get otpDigit => GoogleFonts.inter(
    fontSize:      24,
    fontWeight:    FontWeight.w700,
    letterSpacing: 2,
    color:         AppColors.neutral900,
  );
}
