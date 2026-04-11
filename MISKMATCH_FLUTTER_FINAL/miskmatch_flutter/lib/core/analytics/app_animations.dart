import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

/// MiskMatch — Animation System
///
/// Consistent motion language across the entire app.
/// All durations and curves live here — change once, update everywhere.

abstract class AppAnimations {
  // ── Durations ─────────────────────────────────────────────────────────────
  static const Duration instant   = Duration(milliseconds: 0);
  static const Duration fast      = Duration(milliseconds: 150);
  static const Duration normal    = Duration(milliseconds: 300);
  static const Duration slow      = Duration(milliseconds: 500);
  static const Duration verySlow  = Duration(milliseconds: 800);

  // ── Curves ────────────────────────────────────────────────────────────────
  static const Curve standard     = Curves.easeOutCubic;
  static const Curve decelerate   = Curves.decelerate;
  static const Curve spring       = Curves.elasticOut;
  static const Curve emphasised   = Curves.easeInOutCubicEmphasized;

  // ── Stagger ───────────────────────────────────────────────────────────────
  static Duration stagger(int index, {int baseMs = 50}) =>
      Duration(milliseconds: index * baseMs);

  // ── Page transitions ──────────────────────────────────────────────────────

  /// Slide up — used for bottom sheets and match/chat screens
  static CustomTransitionPage<T> slideUp<T>({
    required LocalKey key,
    required Widget   child,
  }) {
    return CustomTransitionPage<T>(
      key:              key,
      child:            child,
      transitionDuration: normal,
      transitionsBuilder: (context, animation, secondary, child) {
        const begin = Offset(0.0, 1.0);
        const end   = Offset.zero;
        final tween = Tween(begin: begin, end: end)
            .chain(CurveTween(curve: standard));
        return SlideTransition(
          position: animation.drive(tween),
          child:    child,
        );
      },
    );
  }

  /// Fade + scale — used for overlays and dialogs
  static CustomTransitionPage<T> fadeScale<T>({
    required LocalKey key,
    required Widget   child,
  }) {
    return CustomTransitionPage<T>(
      key:              key,
      child:            child,
      transitionDuration: normal,
      transitionsBuilder: (context, animation, secondary, child) {
        return FadeTransition(
          opacity: animation.drive(CurveTween(curve: standard)),
          child:   ScaleTransition(
            scale: animation.drive(
              Tween(begin: 0.92, end: 1.0)
                  .chain(CurveTween(curve: standard)),
            ),
            child: child,
          ),
        );
      },
    );
  }

  /// Slide right — standard iOS-style back
  static CustomTransitionPage<T> slideRight<T>({
    required LocalKey key,
    required Widget   child,
  }) {
    return CustomTransitionPage<T>(
      key:              key,
      child:            child,
      transitionDuration: normal,
      transitionsBuilder: (context, animation, secondary, child) {
        const begin = Offset(1.0, 0.0);
        const end   = Offset.zero;
        final tween = Tween(begin: begin, end: end)
            .chain(CurveTween(curve: standard));
        return SlideTransition(
          position: animation.drive(tween),
          child:    child,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// ANIMATED LIST ITEM  — standard entry animation
// ─────────────────────────────────────────────

class AnimatedListItem extends StatelessWidget {
  const AnimatedListItem({
    super.key,
    required this.child,
    required this.index,
    this.baseDelay = 50,
    this.duration  = const Duration(milliseconds: 350),
  });

  final Widget child;
  final int    index;
  final int    baseDelay;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return child
        .animate(delay: Duration(milliseconds: index * baseDelay))
        .fadeIn(duration: duration)
        .slideY(
          begin:    0.06,
          end:      0,
          duration: duration,
          curve:    AppAnimations.standard,
        );
  }
}

// ─────────────────────────────────────────────
// PULSE ANIMATION WIDGET
// ─────────────────────────────────────────────

class PulseWidget extends StatelessWidget {
  const PulseWidget({
    super.key,
    required this.child,
    this.minScale = 0.97,
    this.maxScale = 1.03,
    this.duration = const Duration(milliseconds: 1200),
  });

  final Widget child;
  final double minScale;
  final double maxScale;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return child
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(begin: minScale, end: maxScale, duration: duration);
  }
}

// ─────────────────────────────────────────────
// SHIMMER LOADING WIDGET
// ─────────────────────────────────────────────

class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width:  width,
      height: height,
      decoration: BoxDecoration(
        color:        Theme.of(context)
            .colorScheme
            .outlineVariant
            .withOpacity(0.3),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(
          duration: const Duration(milliseconds: 1200),
          color:    Colors.white.withOpacity(0.4),
        );
  }
}

// ─────────────────────────────────────────────
// SUCCESS BURST  — shown after major actions
// ─────────────────────────────────────────────

class SuccessBurst extends StatelessWidget {
  const SuccessBurst({
    super.key,
    this.emoji = '✨',
    required this.message,
    this.subMessage,
  });

  final String  emoji;
  final String  message;
  final String? subMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 56))
            .animate()
            .scale(begin: const Offset(0.3, 0.3),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut),

        const SizedBox(height: 16),

        Text(message,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700),
            textAlign: TextAlign.center)
            .animate(delay: 200.ms)
            .fadeIn(duration: 400.ms)
            .slideY(begin: 0.2, end: 0),

        if (subMessage != null) ...[
          const SizedBox(height: 8),
          Text(subMessage!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600]))
              .animate(delay: 350.ms)
              .fadeIn(duration: 400.ms),
        ],
      ],
    );
  }
}
