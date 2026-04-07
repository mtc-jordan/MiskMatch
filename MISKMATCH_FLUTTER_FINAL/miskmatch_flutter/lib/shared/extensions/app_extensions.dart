import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_typography.dart';

// ─────────────────────────────────────────────
// STRING EXTENSIONS
// ─────────────────────────────────────────────

extension StringX on String {
  /// Capitalize first letter only
  String get capitalised =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';

  /// Trim and check not empty
  bool get isNotBlankOrEmpty => trim().isNotEmpty;

  /// First N words
  String firstWords(int n) {
    final words = split(' ');
    if (words.length <= n) return this;
    return '${words.take(n).join(' ')}…';
  }

  /// Mask phone for display: +962791234567 → +962 791 ••• •567
  String get maskedPhone {
    if (length < 8) return this;
    final last4 = substring(length - 4);
    final prefix = substring(0, (length - 4).clamp(0, 6));
    return '$prefix ••• •$last4';
  }
}

// ─────────────────────────────────────────────
// DATETIME EXTENSIONS
// ─────────────────────────────────────────────

extension DateTimeX on DateTime {
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  bool get isYesterday {
    final yest = DateTime.now().subtract(const Duration(days: 1));
    return year == yest.year && month == yest.month && day == yest.day;
  }

  String get chatLabel {
    if (isToday)     return 'Today';
    if (isYesterday) return 'Yesterday';
    return '$day/${month.toString().padLeft(2, '0')}/$year';
  }

  String get timeHHMM {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get shortDate {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '$day ${months[month - 1]}';
  }

  String get fullDate {
    const months = ['January','February','March','April','May','June',
                    'July','August','September','October','November','December'];
    return '$day ${months[month - 1]} $year';
  }

  /// Relative display: "2 mins ago", "3 hours ago", "2 days ago"
  String get timeAgo {
    final diff = DateTime.now().difference(this);
    if (diff.inSeconds < 60)  return 'Just now';
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)    return '${diff.inHours}h ago';
    if (diff.inDays < 7)      return '${diff.inDays}d ago';
    return shortDate;
  }
}

// ─────────────────────────────────────────────
// DURATION EXTENSIONS
// ─────────────────────────────────────────────

extension DurationX on Duration {
  /// "02:35" format
  String get mmss {
    final m = inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// "1d 4h 32m" countdown
  String get countdown {
    if (inDays >= 1)    return '${inDays}d ${inHours.remainder(24)}h';
    if (inHours >= 1)   return '${inHours}h ${inMinutes.remainder(60)}m';
    if (inMinutes >= 1) return '${inMinutes}m ${inSeconds.remainder(60)}s';
    return '${inSeconds}s';
  }
}

// ─────────────────────────────────────────────
// BUILDCONTEXT EXTENSIONS
// ─────────────────────────────────────────────

extension BuildContextX on BuildContext {
  ThemeData      get theme      => Theme.of(this);
  ColorScheme    get colors     => Theme.of(this).colorScheme;
  TextTheme      get textTheme  => Theme.of(this).textTheme;
  MediaQueryData get mq         => MediaQuery.of(this);
  double         get screenW    => mq.size.width;
  double         get screenH    => mq.size.height;
  double         get bottomPad  => mq.padding.bottom;
  bool           get isDark     =>
      Theme.of(this).brightness == Brightness.dark;

  void showSnack(
    String message, {
    Color?   backgroundColor,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content:         Text(message,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.white)),
        backgroundColor: backgroundColor ?? AppColors.neutral900,
        behavior:        SnackBarBehavior.floating,
        duration:        duration,
        shape:           RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void showSuccessSnack(String message) =>
      showSnack(message, backgroundColor: AppColors.success);

  void showErrorSnack(String message) =>
      showSnack(message, backgroundColor: AppColors.error);

  Future<T?> showBottomSheet<T>(Widget child, {bool expand = false}) =>
      showModalBottomSheet<T>(
        context:            this,
        isScrollControlled: expand,
        backgroundColor:    Colors.transparent,
        builder:            (_) => child,
      );
}

// ─────────────────────────────────────────────
// HAPTIC HELPERS
// ─────────────────────────────────────────────

abstract class Haptic {
  static Future<void> light()    => HapticFeedback.lightImpact();
  static Future<void> medium()   => HapticFeedback.mediumImpact();
  static Future<void> heavy()    => HapticFeedback.heavyImpact();
  static Future<void> selection()=> HapticFeedback.selectionClick();

  /// Triggered on successful action (match approved, message sent)
  static Future<void> success() async {
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.lightImpact();
  }

  /// Triggered on error / moderation block
  static Future<void> error() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 60));
    await HapticFeedback.heavyImpact();
  }

  /// Triggered when a decision is confirmed
  static Future<void> confirm() async {
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.lightImpact();
  }
}
