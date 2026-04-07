import 'package:flutter/material.dart';

/// MiskMatch — Brand Color System
/// "ختامه مسك" — Its seal is musk. Quran 83:26
///
/// Rose Garden (light theme): Warm, feminine, welcoming
/// Musk Night (dark theme):   Deep, contemplative, elegant

abstract class AppColors {
  // ── Rose Garden — Light Theme ────────────────────────────────────────────
  /// Deep Rose — primary brand colour (buttons, headers, key UI)
  static const roseDeep = Color(0xFF8B1A4A);

  /// Blush Rose — secondary / interactive states
  static const roseBlush = Color(0xFFC4436A);

  /// Rose Light — soft backgrounds, cards
  static const roseLight = Color(0xFFF2B8C8);

  /// Rose White — primary background
  static const roseWhite = Color(0xFFFBF0F3);

  /// Rose Surface — card / modal surface
  static const roseSurface = Color(0xFFFFF5F7);

  // ── Gold — Islamic accent ────────────────────────────────────────────────
  /// Gold — accents, trust badges, premium indicators
  static const goldPrimary = Color(0xFFC9973A);

  /// Gold Light — subtle highlights
  static const goldLight = Color(0xFFF0C96A);

  /// Gold Dark — pressed states
  static const goldDark = Color(0xFF8B6520);

  // ── Musk Night — Dark Theme ──────────────────────────────────────────────
  /// Midnight — dark background
  static const midnightDeep = Color(0xFF1A0A2E);

  /// Midnight Surface — cards in dark mode
  static const midnightSurface = Color(0xFF2A1245);

  /// Violet — dark theme primary
  static const violetPrimary = Color(0xFF3D1A5E);

  /// Violet Light — dark theme interactive
  static const violetLight = Color(0xFF6B35A8);

  // ── Semantic colours ─────────────────────────────────────────────────────
  static const success = Color(0xFF2E7D32);
  static const successLight = Color(0xFFE8F5E9);
  static const warning = Color(0xFFF57F17);
  static const warningLight = Color(0xFFFFF8E1);
  static const error = Color(0xFFB71C1C);
  static const errorLight = Color(0xFFFFEBEE);
  static const info = Color(0xFF0D47A1);
  static const infoLight = Color(0xFFE3F2FD);

  // ── Neutrals ─────────────────────────────────────────────────────────────
  static const neutral900 = Color(0xFF1A1A2E);
  static const neutral800 = Color(0xFF2A2A4A);
  static const neutral700 = Color(0xFF4A4A6A);
  static const neutral600 = Color(0xFF6A6A8A);
  static const neutral500 = Color(0xFF8A8AAA);
  static const neutral400 = Color(0xFFAAAABB);
  static const neutral300 = Color(0xFFCCCCDD);
  static const neutral100 = Color(0xFFF5F5F8);
  static const white = Color(0xFFFFFFFF);

  // ── Compatibility tier colours ───────────────────────────────────────────
  static const compatExceptional = Color(0xFF2E7D32);
  static const compatStrong      = Color(0xFF388E3C);
  static const compatGood        = Color(0xFFF57F17);
  static const compatModerate    = Color(0xFFE65100);
  static const compatLow         = Color(0xFFB71C1C);
  static const compatIncompat    = Color(0xFF8B1A4A);

  // ── Trust score gradient ─────────────────────────────────────────────────
  static const trustHigh   = Color(0xFF2E7D32);
  static const trustMedium = Color(0xFFF57F17);
  static const trustLow    = Color(0xFFB71C1C);

  // ── Gradients ────────────────────────────────────────────────────────────
  static const roseGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [roseDeep, roseBlush],
  );

  static const goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldDark, goldPrimary, goldLight],
  );

  static const midnightGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [midnightDeep, violetPrimary],
  );

  /// Shimmer gradient — used for loading skeletons
  static const shimmerGradient = LinearGradient(
    colors: [neutral100, neutral300, neutral100],
    stops: [0.0, 0.5, 1.0],
  );
}
