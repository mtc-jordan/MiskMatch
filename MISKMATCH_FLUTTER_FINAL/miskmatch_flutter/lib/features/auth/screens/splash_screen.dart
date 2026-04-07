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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end:   Alignment.bottomCenter,
            colors: [
              AppColors.roseWhite,
              Color(0xFFF5D5E0),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Brand mark ─────────────────────────────────────────────
              _BrandMark()
                  .animate()
                  .fadeIn(duration: 800.ms, curve: Curves.easeOut)
                  .slideY(begin: 0.2, end: 0, duration: 800.ms, curve: Curves.easeOutCubic),

              const Spacer(flex: 2),

              // ── Loading indicator ──────────────────────────────────────
              SizedBox(
                width:  120,
                child: LinearProgressIndicator(
                  backgroundColor: AppColors.roseLight.withOpacity(0.4),
                  color:           AppColors.roseDeep.withOpacity(0.6),
                  minHeight:       2,
                  borderRadius:    BorderRadius.circular(2),
                ),
              )
                  .animate(delay: 600.ms)
                  .fadeIn(duration: 400.ms),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo mark — stylised musk seal
        Container(
          width:  100,
          height: 100,
          decoration: BoxDecoration(
            gradient: AppColors.roseGradient,
            shape:    BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color:      AppColors.roseDeep.withOpacity(0.3),
                blurRadius: 32,
                offset:     const Offset(0, 8),
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'مـ',
              style: TextStyle(
                fontFamily: 'Scheherazade',
                fontSize:   48,
                color:      AppColors.white,
                fontWeight: FontWeight.w700,
                height:     1.2,
              ),
            ),
          ),
        ),

        const SizedBox(height: 28),

        // App name
        Text(
          'MiskMatch',
          style: AppTypography.headlineLarge.copyWith(
            color:       AppColors.roseDeep,
            fontWeight:  FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),

        const SizedBox(height: 6),

        // Arabic name
        const Text(
          'مسك ماتش',
          style: TextStyle(
            fontFamily: 'Scheherazade',
            fontSize:   20,
            color:      AppColors.roseBlush,
            height:     1.6,
          ),
        ),

        const SizedBox(height: 20),

        // Tagline — Quranic reference
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color:        AppColors.goldPrimary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(24),
            border:       Border.all(
              color: AppColors.goldPrimary.withOpacity(0.2),
            ),
          ),
          child: Column(
            children: [
              const Text(
                'ختامه مسك',
                style: TextStyle(
                  fontFamily: 'Scheherazade',
                  fontSize:   18,
                  color:      AppColors.goldPrimary,
                  fontWeight: FontWeight.w600,
                  height:     1.8,
                ),
              ),
              Text(
                'Sealed with musk — Quran 83:26',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.goldDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
