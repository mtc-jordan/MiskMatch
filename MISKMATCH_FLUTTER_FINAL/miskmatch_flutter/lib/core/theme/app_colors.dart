import 'package:flutter/material.dart';

/// MiskMatch — Brand Color System
/// "ختامه مسك" — Its seal is musk. Quran 83:26

abstract class AppColors {
  // ── Rose ─────────────────────────────────────────────────────────────────
  static const roseDeep   = Color(0xFF8B1A4A);
  static const roseBlush  = Color(0xFFC4436A);
  static const roseLight  = Color(0xFFF4D0DC);
  static const rosePale   = Color(0xFFFBF0F3);

  // ── Gold — Islamic accent ────────────────────────────────────────────────
  static const goldPrimary = Color(0xFFC9973A);
  static const goldLight   = Color(0xFFE8C97A);
  static const goldDark    = Color(0xFF8B6520);

  // ── Midnight ─────────────────────────────────────────────────────────────
  static const midnightDeep = Color(0xFF1A0A2E);
  static const midnightMid  = Color(0xFF2D1459);

  // ── Neutrals ─────────────────────────────────────────────────────────────
  static const neutral900 = Color(0xFF1A1A2E);
  static const neutral700 = Color(0xFF3D3060);
  static const neutral500 = Color(0xFF7A6A8A);
  static const neutral300 = Color(0xFFC8B8D8);
  static const neutral100 = Color(0xFFF0EBF6);
  static const white      = Color(0xFFFFFFFF);

  // ── Semantic ─────────────────────────────────────────────────────────────
  static const success    = Color(0xFF1B7F4A);
  static const error      = Color(0xFFC0392B);
  static const errorLight = Color(0xFFFDECEA);

  // ── Aliases (backward compat) ─────────────────────────────────────────
  static const roseWhite        = rosePale;
  static const roseSurface      = white;
  static const midnightSurface  = midnightMid;
  static const neutral800       = Color(0xFF2D2D4E);
  static const neutral600       = Color(0xFF5A4D6E);
  static const neutral400       = Color(0xFFA898B8);
  static const violetPrimary    = midnightMid;

  // ── Compatibility tier colours ──────────────────────────────────────────
  static const compatExceptional = goldPrimary;
  static const compatStrong      = success;
  static const compatGood        = roseDeep;
  static const compatModerate    = neutral500;
  static const compatLow         = error;

  // ── Gradients ────────────────────────────────────────────────────────────
  static const roseGradient = LinearGradient(
    begin: Alignment.topLeft,
    end:   Alignment.bottomRight,
    colors: [roseDeep, roseBlush],
  );

  static const goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end:   Alignment.bottomRight,
    colors: [goldPrimary, goldLight],
  );

  static const nightGradient = LinearGradient(
    begin: Alignment.topCenter,
    end:   Alignment.bottomCenter,
    colors: [midnightDeep, midnightMid],
  );

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end:   Alignment.bottomRight,
    colors: [roseDeep, midnightDeep],
  );
}
