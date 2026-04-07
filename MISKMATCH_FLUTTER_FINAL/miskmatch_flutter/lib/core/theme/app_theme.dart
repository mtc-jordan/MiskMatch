import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_typography.dart';

/// MiskMatch — Material 3 Theme System
///
/// Two themes:
///   roseGardenTheme  — light, warm, feminine (default)
///   muskNightTheme   — dark, contemplative, elegant

class AppTheme {
  AppTheme._();

  // ═══════════════════════════════════════════════════════════════════════════
  // ROSE GARDEN — Light Theme
  // ═══════════════════════════════════════════════════════════════════════════

  static ThemeData get roseGardenTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary:          AppColors.roseDeep,
      onPrimary:        AppColors.white,
      primaryContainer: AppColors.roseLight,
      onPrimaryContainer: AppColors.roseDeep,
      secondary:        AppColors.goldPrimary,
      onSecondary:      AppColors.white,
      secondaryContainer: AppColors.goldLight,
      onSecondaryContainer: AppColors.goldDark,
      tertiary:         AppColors.roseBlush,
      onTertiary:       AppColors.white,
      error:            AppColors.error,
      onError:          AppColors.white,
      errorContainer:   AppColors.errorLight,
      onErrorContainer: AppColors.error,
      surface:          AppColors.roseSurface,
      onSurface:        AppColors.neutral900,
      surfaceContainerHighest: AppColors.roseWhite,
      onSurfaceVariant: AppColors.neutral700,
      outline:          AppColors.neutral300,
      outlineVariant:   AppColors.roseLight,
      shadow:           AppColors.neutral900,
      scrim:            AppColors.neutral900,
      inverseSurface:   AppColors.neutral900,
      onInverseSurface: AppColors.white,
      inversePrimary:   AppColors.roseLight,
    );

    return _buildTheme(colorScheme, Brightness.light);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MUSK NIGHT — Dark Theme
  // ═══════════════════════════════════════════════════════════════════════════

  static ThemeData get muskNightTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary:          AppColors.roseLight,
      onPrimary:        AppColors.roseDeep,
      primaryContainer: AppColors.violetPrimary,
      onPrimaryContainer: AppColors.roseLight,
      secondary:        AppColors.goldLight,
      onSecondary:      AppColors.goldDark,
      secondaryContainer: AppColors.goldDark,
      onSecondaryContainer: AppColors.goldLight,
      tertiary:         AppColors.roseBlush,
      onTertiary:       AppColors.white,
      error:            AppColors.error,
      onError:          AppColors.white,
      errorContainer:   Color(0xFF5C0A0A),
      onErrorContainer: AppColors.errorLight,
      surface:          AppColors.midnightSurface,
      onSurface:        AppColors.white,
      surfaceContainerHighest: AppColors.midnightDeep,
      onSurfaceVariant: AppColors.neutral300,
      outline:          AppColors.neutral700,
      outlineVariant:   AppColors.violetPrimary,
      shadow:           AppColors.midnightDeep,
      scrim:            AppColors.midnightDeep,
      inverseSurface:   AppColors.neutral100,
      onInverseSurface: AppColors.neutral900,
      inversePrimary:   AppColors.roseDeep,
    );

    return _buildTheme(colorScheme, Brightness.dark);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SHARED THEME BUILDER
  // ═══════════════════════════════════════════════════════════════════════════

  static ThemeData _buildTheme(ColorScheme colorScheme, Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final textTheme = _buildTextTheme(colorScheme);

    return ThemeData(
      useMaterial3:  true,
      colorScheme:   colorScheme,
      textTheme:     textTheme,
      brightness:    brightness,

      // ── AppBar ────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        elevation:          0,
        scrolledUnderElevation: 0,
        backgroundColor:    isLight ? AppColors.roseWhite : AppColors.midnightDeep,
        foregroundColor:    colorScheme.onSurface,
        titleTextStyle:     AppTypography.titleLarge.copyWith(
          color: colorScheme.onSurface,
        ),
        systemOverlayStyle: isLight
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        actionsIconTheme: IconThemeData(color: colorScheme.primary),
      ),

      // ── Scaffold ──────────────────────────────────────────────────────────
      scaffoldBackgroundColor:
          isLight ? AppColors.roseWhite : AppColors.midnightDeep,

      // ── Elevated Button ───────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor:  colorScheme.primary,
          foregroundColor:  colorScheme.onPrimary,
          elevation:        0,
          shadowColor:      Colors.transparent,
          minimumSize:      const Size(double.infinity, 56),
          shape:            RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: AppTypography.labelLarge.copyWith(fontSize: 16),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),

      // ── Outlined Button ───────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          minimumSize:     const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: BorderSide(color: colorScheme.primary, width: 1.5),
          textStyle: AppTypography.labelLarge.copyWith(fontSize: 16),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),

      // ── Text Button ───────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: AppTypography.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // ── Input Decoration ─────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled:      true,
        fillColor:   isLight ? AppColors.white : AppColors.midnightSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        labelStyle: AppTypography.bodyMedium.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: colorScheme.onSurfaceVariant.withOpacity(0.6),
        ),
        errorStyle: AppTypography.bodySmall.copyWith(
          color: colorScheme.error,
        ),
        prefixIconColor: colorScheme.onSurfaceVariant,
        suffixIconColor: colorScheme.onSurfaceVariant,
      ),

      // ── Card ──────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation:  0,
        color:      isLight ? AppColors.white : AppColors.midnightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isLight
                ? AppColors.roseLight.withOpacity(0.5)
                : AppColors.violetPrimary.withOpacity(0.3),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),

      // ── BottomNavigationBar ───────────────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor:      isLight ? AppColors.white : AppColors.midnightSurface,
        selectedItemColor:     colorScheme.primary,
        unselectedItemColor:   colorScheme.onSurfaceVariant,
        type:                  BottomNavigationBarType.fixed,
        elevation:             8,
        selectedLabelStyle:    AppTypography.labelSmall.copyWith(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle:  AppTypography.labelSmall,
      ),

      // ── NavigationBar (Material 3) ────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor:       isLight ? AppColors.white : AppColors.midnightSurface,
        indicatorColor:        colorScheme.primaryContainer,
        surfaceTintColor:      Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTypography.labelSmall.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            );
          }
          return AppTypography.labelSmall.copyWith(
            color: colorScheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.primary, size: 24);
          }
          return IconThemeData(color: colorScheme.onSurfaceVariant, size: 24);
        }),
      ),

      // ── Chip ──────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor:   isLight ? AppColors.roseWhite : AppColors.violetPrimary,
        selectedColor:     colorScheme.primaryContainer,
        labelStyle:        AppTypography.labelMedium,
        padding:           const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape:             RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),

      // ── Divider ───────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color:     colorScheme.outline.withOpacity(0.5),
        thickness: 1,
        space:     1,
      ),

      // ── Dialog ────────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: isLight ? AppColors.white : AppColors.midnightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        elevation: 3,
        titleTextStyle: AppTypography.headlineSmall.copyWith(
          color: colorScheme.onSurface,
        ),
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),

      // ── SnackBar ──────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior:        SnackBarBehavior.floating,
        backgroundColor: isLight ? AppColors.neutral900 : AppColors.neutral100,
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: isLight ? AppColors.white : AppColors.neutral900,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // ── FloatingActionButton ──────────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation:       2,
        shape:           RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      // ── Switch ────────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.primary;
          return colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primaryContainer;
          }
          return colorScheme.surfaceContainerHighest;
        }),
      ),

      // ── ProgressIndicator ─────────────────────────────────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color:              colorScheme.primary,
        linearTrackColor:   colorScheme.primaryContainer,
        circularTrackColor: colorScheme.primaryContainer,
      ),

      // ── Tooltip ───────────────────────────────────────────────────────────
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: AppTypography.bodySmall.copyWith(
          color: colorScheme.onInverseSurface,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TEXT THEME BUILDER
  // ═══════════════════════════════════════════════════════════════════════════

  static TextTheme _buildTextTheme(ColorScheme colorScheme) {
    return TextTheme(
      displayLarge:  AppTypography.displayLarge.copyWith(color: colorScheme.onSurface),
      displayMedium: AppTypography.displayMedium.copyWith(color: colorScheme.onSurface),
      displaySmall:  AppTypography.headlineLarge.copyWith(color: colorScheme.onSurface),
      headlineLarge: AppTypography.headlineLarge.copyWith(color: colorScheme.onSurface),
      headlineMedium:AppTypography.headlineMedium.copyWith(color: colorScheme.onSurface),
      headlineSmall: AppTypography.headlineSmall.copyWith(color: colorScheme.onSurface),
      titleLarge:    AppTypography.titleLarge.copyWith(color: colorScheme.onSurface),
      titleMedium:   AppTypography.titleMedium.copyWith(color: colorScheme.onSurface),
      titleSmall:    AppTypography.titleSmall.copyWith(color: colorScheme.onSurface),
      bodyLarge:     AppTypography.bodyLarge.copyWith(color: colorScheme.onSurfaceVariant),
      bodyMedium:    AppTypography.bodyMedium.copyWith(color: colorScheme.onSurfaceVariant),
      bodySmall:     AppTypography.bodySmall.copyWith(color: colorScheme.onSurfaceVariant),
      labelLarge:    AppTypography.labelLarge.copyWith(color: colorScheme.onSurface),
      labelMedium:   AppTypography.labelMedium.copyWith(color: colorScheme.onSurfaceVariant),
      labelSmall:    AppTypography.labelSmall.copyWith(color: colorScheme.onSurfaceVariant),
    );
  }
}

// ─────────────────────────────────────────────
// SPACING & RADIUS CONSTANTS
// ─────────────────────────────────────────────

abstract class AppSpacing {
  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 16;
  static const double lg  = 24;
  static const double xl  = 32;
  static const double xxl = 48;

  static const double screenPadding = 20;
  static const double cardPadding   = 16;
  static const double sectionGap    = 32;

  // Bottom nav safe area
  static const double bottomNavHeight = 80;
}

abstract class AppRadius {
  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 12;
  static const double lg  = 16;
  static const double xl  = 20;
  static const double xxl = 28;
  static const double full = 999;

  static const BorderRadius cardRadius  = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius buttonRadius= BorderRadius.all(Radius.circular(lg));
  static const BorderRadius inputRadius = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius chipRadius  = BorderRadius.all(Radius.circular(full));
  static const BorderRadius bottomSheet = BorderRadius.vertical(top: Radius.circular(xxl));
}

abstract class AppShadows {
  static List<BoxShadow> get card => [
    BoxShadow(
      color: AppColors.roseDeep.withOpacity(0.06),
      blurRadius: 20,
      offset: const Offset(0, 4),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get elevated => [
    BoxShadow(
      color: AppColors.roseDeep.withOpacity(0.12),
      blurRadius: 32,
      offset: const Offset(0, 8),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get subtle => [
    BoxShadow(
      color: AppColors.neutral900.withOpacity(0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
}
