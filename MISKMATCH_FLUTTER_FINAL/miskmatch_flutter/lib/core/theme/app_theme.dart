import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_typography.dart';

/// MiskMatch — Material 3 Theme System
///
/// roseGardenTheme  — light, warm, Islamic luxury
/// muskNightTheme   — dark, contemplative, elegant

class AppTheme {
  AppTheme._();

  // ═════════════════════════════════════════════════════════════════════════
  // ROSE GARDEN — Light Theme
  // ═════════════════════════════════════════════════════════════════════════

  static ThemeData get roseGardenTheme {
    const colorScheme = ColorScheme(
      brightness:             Brightness.light,
      primary:                AppColors.roseDeep,
      onPrimary:              AppColors.white,
      primaryContainer:       AppColors.roseLight,
      onPrimaryContainer:     AppColors.roseDeep,
      secondary:              AppColors.goldPrimary,
      onSecondary:            AppColors.white,
      secondaryContainer:     AppColors.goldLight,
      onSecondaryContainer:   AppColors.goldDark,
      tertiary:               AppColors.roseBlush,
      onTertiary:             AppColors.white,
      error:                  AppColors.error,
      onError:                AppColors.white,
      errorContainer:         AppColors.errorLight,
      onErrorContainer:       AppColors.error,
      surface:                AppColors.white,
      onSurface:              AppColors.neutral900,
      surfaceContainerHighest:AppColors.rosePale,
      onSurfaceVariant:       AppColors.neutral700,
      outline:                AppColors.neutral300,
      outlineVariant:         AppColors.neutral100,
      shadow:                 AppColors.neutral900,
      scrim:                  AppColors.neutral900,
      inverseSurface:         AppColors.neutral900,
      onInverseSurface:       AppColors.white,
      inversePrimary:         AppColors.roseLight,
    );
    return _buildTheme(colorScheme, Brightness.light);
  }

  // ═════════════════════════════════════════════════════════════════════════
  // MUSK NIGHT — Dark Theme
  // ═════════════════════════════════════════════════════════════════════════

  static ThemeData get muskNightTheme {
    const colorScheme = ColorScheme(
      brightness:             Brightness.dark,
      primary:                AppColors.roseBlush,       // lighter rose for contrast
      onPrimary:              AppColors.white,
      primaryContainer:       AppColors.midnightMid,
      onPrimaryContainer:     AppColors.roseLight,
      secondary:              AppColors.goldLight,
      onSecondary:            AppColors.goldDark,
      secondaryContainer:     AppColors.goldDark,
      onSecondaryContainer:   AppColors.goldLight,
      tertiary:               AppColors.roseBlush,
      onTertiary:             AppColors.white,
      error:                  AppColors.error,
      onError:                AppColors.white,
      errorContainer:         Color(0xFF5C0A0A),
      onErrorContainer:       AppColors.errorLight,
      surface:                AppColors.midnightMid,     // cards, sheets
      onSurface:              AppColors.white,
      surfaceContainerHighest:AppColors.midnightDeep,
      onSurfaceVariant:       AppColors.neutral300,
      outline:                AppColors.neutral700,
      outlineVariant:         Color(0xFF3D1A6B),         // surfaceVariant
      shadow:                 AppColors.midnightDeep,
      scrim:                  AppColors.midnightDeep,
      inverseSurface:         AppColors.neutral100,
      onInverseSurface:       AppColors.neutral900,
      inversePrimary:         AppColors.roseDeep,
    );
    return _buildTheme(colorScheme, Brightness.dark);
  }

  // ═════════════════════════════════════════════════════════════════════════
  // SHARED BUILDER
  // ═════════════════════════════════════════════════════════════════════════

  static ThemeData _buildTheme(ColorScheme cs, Brightness brightness) {
    final isLight = brightness == Brightness.light;

    return ThemeData(
      useMaterial3: true,
      colorScheme:  cs,
      brightness:   brightness,

      scaffoldBackgroundColor:
          isLight ? AppColors.rosePale : AppColors.midnightDeep,

      // ── AppBar ──────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        elevation:              0,
        scrolledUnderElevation: 0,
        backgroundColor: isLight ? AppColors.rosePale : AppColors.midnightDeep,
        foregroundColor: cs.onSurface,
        titleTextStyle:  AppTypography.titleLarge.copyWith(color: cs.onSurface),
        systemOverlayStyle:
            isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
        iconTheme:        IconThemeData(color: cs.onSurface),
        actionsIconTheme: IconThemeData(color: cs.primary),
      ),

      // ── Input ───────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled:         true,
        fillColor:      isLight ? AppColors.white : AppColors.midnightMid,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide:   BorderSide(color: cs.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide:   BorderSide(
            color: isLight ? AppColors.neutral300 : AppColors.neutral700,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide:   BorderSide(color: cs.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide:   const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide:   const BorderSide(color: AppColors.error, width: 2),
        ),
        labelStyle: AppTypography.bodyMedium.copyWith(
          color: isLight ? AppColors.neutral500 : AppColors.neutral400),
        floatingLabelStyle: AppTypography.labelSmall.copyWith(
          fontSize: 11, color: cs.primary,
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: (isLight ? AppColors.neutral500 : AppColors.neutral400)
              .withOpacity(0.6),
        ),
        errorStyle:     AppTypography.bodySmall.copyWith(color: AppColors.error),
        prefixIconColor: isLight ? AppColors.neutral500 : AppColors.neutral400,
        suffixIconColor: isLight ? AppColors.neutral500 : AppColors.neutral400,
      ),

      // ── Card ────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation:     0,
        color:         cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(
            color: isLight
                ? AppColors.neutral100
                : AppColors.neutral500.withOpacity(0.3),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        margin:       EdgeInsets.zero,
      ),

      // ── Buttons ─────────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          elevation:       0,
          shadowColor:     Colors.transparent,
          minimumSize:     const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          textStyle: AppTypography.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          minimumSize:     const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          side: BorderSide(color: cs.primary, width: 1.5),
          textStyle: AppTypography.labelLarge.copyWith(color: cs.primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          textStyle:       AppTypography.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // ── Navigation ──────────────────────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor:    cs.surface,
        selectedItemColor:   cs.primary,
        unselectedItemColor: cs.onSurfaceVariant,
        type:                BottomNavigationBarType.fixed,
        elevation:           8,
        selectedLabelStyle:  AppTypography.labelSmall.copyWith(
          fontWeight: FontWeight.w600),
        unselectedLabelStyle: AppTypography.labelSmall,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor:  cs.surface,
        indicatorColor:    cs.primaryContainer,
        surfaceTintColor:  Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTypography.labelSmall.copyWith(
              color: cs.primary, fontWeight: FontWeight.w600);
          }
          return AppTypography.labelSmall.copyWith(color: cs.onSurfaceVariant);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: cs.primary, size: 24);
          }
          return IconThemeData(color: cs.onSurfaceVariant, size: 24);
        }),
      ),

      // ── Chip ────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: isLight ? AppColors.rosePale : AppColors.midnightMid,
        selectedColor:    cs.primaryContainer,
        labelStyle:       AppTypography.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: const StadiumBorder(),
      ),

      // ── Divider ─────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color:     isLight ? AppColors.neutral100 : AppColors.neutral700,
        thickness: 1,
        space:     1,
      ),

      // ── Dialog ──────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        elevation:         3,
        titleTextStyle:    AppTypography.headlineSmall.copyWith(color: cs.onSurface),
        contentTextStyle:  AppTypography.bodyMedium.copyWith(color: cs.onSurfaceVariant),
      ),

      // ── SnackBar ────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior:        SnackBarBehavior.floating,
        backgroundColor: isLight ? AppColors.neutral900 : AppColors.neutral100,
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: isLight ? AppColors.white : AppColors.neutral900),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // ── Switch ──────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.white;
          return isLight ? AppColors.neutral300 : AppColors.neutral500;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.roseDeep;
          return isLight ? AppColors.neutral100 : AppColors.neutral700;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      // ── Progress ────────────────────────────────────────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color:              cs.primary,
        linearTrackColor:   cs.primaryContainer,
        circularTrackColor: cs.primaryContainer,
      ),

      // ── FAB ─────────────────────────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation:       2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),

      // ── BottomSheet ─────────────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.bottomSheet,
        ),
      ),

      // ── Tooltip ─────────────────────────────────────────────────────────
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: cs.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: AppTypography.bodySmall.copyWith(color: cs.onInverseSurface),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// MISK THEME EXTENSION — convenient theme access
// ─────────────────────────────────────────────

extension MiskTheme on BuildContext {
  ThemeData      get theme => Theme.of(this);
  ColorScheme    get colors => Theme.of(this).colorScheme;
  bool           get isDark => Theme.of(this).brightness == Brightness.dark;

  // ── Scaffold / surface ─────────────────────
  Color get scaffoldColor => theme.scaffoldBackgroundColor;
  Color get surfaceColor  => colors.surface;

  // ── Text colors ────────────────────────────
  Color get onSurface     => colors.onSurface;       // primary text
  Color get subtleText    => colors.onSurfaceVariant; // secondary text
  Color get mutedText     => isDark                   // muted text
      ? AppColors.neutral400
      : AppColors.neutral500;
  Color get hintText      => isDark
      ? AppColors.neutral500
      : AppColors.neutral500;

  // ── Card styling ───────────────────────────
  Color get cardSurface   => colors.surface;
  Color get cardBorder    => isDark
      ? AppColors.neutral500.withOpacity(0.3)
      : AppColors.neutral100;
  List<BoxShadow> get cardShadow => isDark
      ? []  // no shadows in dark mode
      : AppShadows.card;

  // ── Subtle backgrounds ─────────────────────
  Color get subtleBg => isDark
      ? AppColors.midnightMid
      : AppColors.neutral100;
  Color get chipBg => isDark
      ? colors.outlineVariant  // surfaceVariant #3D1A6B
      : AppColors.rosePale;

  // ── Handle / divider ───────────────────────
  Color get handleColor => isDark
      ? AppColors.neutral500.withOpacity(0.4)
      : AppColors.neutral300.withOpacity(0.5);

  // ── Error light bg ─────────────────────────
  Color get errorLightBg => isDark
      ? AppColors.error.withOpacity(0.15)
      : AppColors.errorLight;
}

// ─────────────────────────────────────────────
// SPACING
// ─────────────────────────────────────────────

abstract class AppSpacing {
  static const double screenPadding  = 20;
  static const double cardPadding    = 18;
  static const double sectionGap     = 24;
  static const double itemGap        = 12;
  static const double tinyGap        = 6;

  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 16;
  static const double lg  = 24;
  static const double xl  = 32;
  static const double xxl = 48;

  static const double bottomNavHeight = 80;
}

// ─────────────────────────────────────────────
// BORDER RADIUS
// ─────────────────────────────────────────────

abstract class AppRadius {
  static const double card   = 20;
  static const double button = 16;
  static const double chip   = 100;
  static const double input  = 14;
  static const double xl     = 24;
  static const double lg     = 16;
  static const double xxl    = 28;
  static const double md     = 12;
  static const double sm     = 8;
  static const double full   = 999;

  static const BorderRadius cardRadius   = BorderRadius.all(Radius.circular(card));
  static const BorderRadius buttonRadius = BorderRadius.all(Radius.circular(button));
  static const BorderRadius inputRadius  = BorderRadius.all(Radius.circular(input));
  static const BorderRadius chipRadius   = BorderRadius.all(Radius.circular(chip));
  static const BorderRadius bottomSheet  = BorderRadius.vertical(top: Radius.circular(xl));
}

// ─────────────────────────────────────────────
// SHADOWS
// ─────────────────────────────────────────────

abstract class AppShadows {
  static List<BoxShadow> get card => [
    BoxShadow(
      color:      AppColors.roseDeep.withOpacity(0.10),
      blurRadius: 20,
      offset:     const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get elevated => [
    BoxShadow(
      color:      AppColors.roseDeep.withOpacity(0.16),
      blurRadius: 32,
      offset:     const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get gold => [
    BoxShadow(
      color:      AppColors.goldPrimary.withOpacity(0.25),
      blurRadius: 20,
      offset:     const Offset(0, 4),
    ),
  ];
}

