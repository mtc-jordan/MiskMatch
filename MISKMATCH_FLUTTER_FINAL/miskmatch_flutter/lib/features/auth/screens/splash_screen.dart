import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_typography.dart';

/// Bismillah splash screen.
/// Shows the brand mark while the auth provider restores session state.
/// GoRouter redirect handles navigation once AuthState is resolved.

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Hero gradient background ────────────────────────────────────
          Container(
            decoration: const BoxDecoration(gradient: AppColors.heroGradient),
          ),

          // ── Floating rose circles (ambient) ────────────────────────────
          const _FloatingCircles(),

          // ── Main content ───────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),
                const _BrandSequence(),
                const Spacer(flex: 3),

                // ── Pulsing dots loader ──────────────────────────────────
                const _PulsingDots()
                    .animate(delay: 1200.ms)
                    .fadeIn(duration: 400.ms),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// BRAND ANIMATION SEQUENCE
// ─────────────────────────────────────────────

class _BrandSequence extends StatelessWidget {
  const _BrandSequence();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Rose circle — scales in elasticOut 700ms
        Container(
          width: 120, height: 120,
          decoration: BoxDecoration(
            gradient: AppColors.roseGradient,
            shape:    BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color:      AppColors.roseDeep.withOpacity(0.4),
                blurRadius: 40,
                offset:     const Offset(0, 8),
                spreadRadius: 4,
              ),
            ],
          ),
          // 2. Arabic مـ fades in inside circle — delay 200ms
          child: Center(
            child: const Text(
              'مـ',
              style: TextStyle(
                fontFamily:  'Scheherazade',
                fontSize:    52,
                color:       AppColors.white,
                fontWeight:  FontWeight.w700,
                height:      1.2,
              ),
            )
                .animate(delay: 200.ms)
                .fadeIn(duration: 500.ms)
                .scale(
                  begin: const Offset(0.6, 0.6),
                  end:   const Offset(1.0, 1.0),
                  duration: 500.ms,
                  curve: Curves.easeOutCubic,
                ),
          ),
        )
            .animate()
            .scale(
              begin:    const Offset(0.4, 0.4),
              end:      const Offset(1.0, 1.0),
              duration: 700.ms,
              curve:    Curves.elasticOut,
            )
            .fadeIn(duration: 300.ms),

        const SizedBox(height: 28),

        // 3. "MiskMatch" — slides up, delay 400ms
        Text(
          'MiskMatch',
          style: const TextStyle(
            fontFamily:    'Georgia',
            fontSize:      36,
            fontWeight:    FontWeight.w700,
            color:         AppColors.white,
            letterSpacing: -0.5,
          ),
        )
            .animate(delay: 400.ms)
            .fadeIn(duration: 500.ms)
            .slideY(begin: 0.4, end: 0, duration: 500.ms,
                    curve: Curves.easeOutCubic),

        const SizedBox(height: 16),

        // 4. Gold divider — draws from centre, delay 600ms
        Container(
          width: 60, height: 2,
          decoration: BoxDecoration(
            gradient: AppColors.goldGradient,
            borderRadius: BorderRadius.circular(1),
          ),
        )
            .animate(delay: 600.ms)
            .scaleX(begin: 0, end: 1, duration: 400.ms,
                    curve: Curves.easeOutCubic)
            .fadeIn(duration: 200.ms),

        const SizedBox(height: 16),

        // 5. ختامه مسك — delay 800ms
        const Text(
          'ختامه مسك',
          style: TextStyle(
            fontFamily:  'Scheherazade',
            fontSize:    20,
            color:       AppColors.goldLight,
            fontWeight:  FontWeight.w600,
            height:      2.0,
          ),
        )
            .animate(delay: 800.ms)
            .fadeIn(duration: 500.ms),

        const SizedBox(height: 6),

        // 6. English tagline — delay 1000ms
        Text(
          'Sealed with musk. — Quran 83:26',
          style: AppTypography.bodySmall.copyWith(
            color:      AppColors.neutral300,
            fontStyle:  FontStyle.italic,
            fontSize:   12,
          ),
        )
            .animate(delay: 1000.ms)
            .fadeIn(duration: 500.ms),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// PULSING DOTS LOADER
// ─────────────────────────────────────────────

class _PulsingDots extends StatelessWidget {
  const _PulsingDots();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Container(
          width: 8, height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: const BoxDecoration(
            color: AppColors.roseBlush,
            shape: BoxShape.circle,
          ),
        )
            .animate(
              onPlay: (c) => c.repeat(reverse: true),
              delay: (i * 200).ms,
            )
            .scaleXY(begin: 0.6, end: 1.0, duration: 600.ms,
                     curve: Curves.easeInOut)
            .fadeIn(duration: 300.ms);
      }),
    );
  }
}

// ─────────────────────────────────────────────
// FLOATING AMBIENT CIRCLES
// ─────────────────────────────────────────────

class _FloatingCircles extends StatelessWidget {
  const _FloatingCircles();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Top-right circle
        Positioned(
          top: -40, right: -50,
          child: _circle(180, 0.06),
        ),
        // Bottom-left circle
        Positioned(
          bottom: -60, left: -70,
          child: _circle(220, 0.08),
        ),
        // Mid-right circle
        Positioned(
          top: MediaQuery.of(context).size.height * 0.35,
          right: -30,
          child: _circle(100, 0.12),
        ),
      ],
    );
  }

  Widget _circle(double size, double opacity) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.roseBlush.withOpacity(opacity),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(
          begin: 1.0, end: 1.15,
          duration: 3000.ms,
          curve: Curves.easeInOut,
        );
  }
}
