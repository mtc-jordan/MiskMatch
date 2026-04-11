import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:miskmatch/core/router/app_router.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/shared/widgets/common_widgets.dart';
import 'package:miskmatch/features/auth/providers/auth_provider.dart';
import 'package:miskmatch/l10n/generated/app_localizations.dart';

/// Niyyah (intention) screen — the most spiritually important screen.
/// Designed with reverence. No rush. No clutter.

class NiyyahScreen extends ConsumerStatefulWidget {
  const NiyyahScreen({super.key});

  @override
  ConsumerState<NiyyahScreen> createState() => _NiyyahScreenState();
}

class _NiyyahScreenState extends ConsumerState<NiyyahScreen> {
  int?   _selected;
  final  _customCtrl = TextEditingController();

  List<String> _intentions(BuildContext context) {
    final l = S.of(context);
    return [l.niyyahMarriage, l.niyyahRighteous, l.niyyahDeen];
  }

  String? get _niyyah {
    if (_selected != null) return 'selected';
    if (_customCtrl.text.trim().isNotEmpty) return _customCtrl.text.trim();
    return null;
  }

  void _submit() {
    context.go(AppRoutes.waliSetup);
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Night gradient background ─────────────────────────────────
          Container(decoration: const BoxDecoration(gradient: AppColors.nightGradient)),

          // ── Geometric pattern overlay ──────────────────────────────────
          const _GeometricPattern(),

          // ── Soft rose glow top-right ──────────────────────────────────
          Positioned(
            top: -60, right: -60,
            child: Container(
              width: 220, height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.roseDeep.withOpacity(0.08),
              ),
            ),
          ),

          // ── Main content ──────────────────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPadding),
              child: Column(
                children: [
                  const SizedBox(height: 40),

                  // 1. Gold ornament — draws in from centre
                  const _GoldOrnament()
                      .animate()
                      .scaleX(begin: 0, end: 1, duration: 600.ms,
                              curve: Curves.easeOutCubic)
                      .fadeIn(duration: 300.ms),

                  const SizedBox(height: 32),

                  // 2. Arabic du'a
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text(
                      S.of(context).bismillahDua,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Scheherazade',
                        fontSize:   22,
                        color:      AppColors.goldLight,
                        height:     2.2,
                      ),
                    ),
                  )
                      .animate(delay: 600.ms)
                      .fadeIn(duration: 800.ms),

                  const SizedBox(height: 8),

                  // 3. Translation
                  Text(
                    S.of(context).bismillahTranslation,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall.copyWith(
                      color:     AppColors.neutral300,
                      fontStyle: FontStyle.italic,
                      fontSize:  12,
                    ),
                  )
                      .animate(delay: 800.ms)
                      .fadeIn(duration: 400.ms),

                  const SizedBox(height: 28),

                  // 4. Rose divider
                  Container(
                    width: 80, height: 1,
                    color: AppColors.roseDeep.withOpacity(0.4),
                  )
                      .animate(delay: 1000.ms)
                      .scaleX(begin: 0, end: 1, duration: 400.ms)
                      .fadeIn(duration: 200.ms),

                  const SizedBox(height: 28),

                  // 5. Heading
                  Text(
                    S.of(context).setYourNiyyah,
                    style: const TextStyle(
                      fontFamily:  'Georgia',
                      fontSize:    28,
                      fontWeight:  FontWeight.w700,
                      color:       AppColors.white,
                    ),
                  )
                      .animate(delay: 1100.ms)
                      .fadeIn(duration: 500.ms)
                      .slideY(begin: 0.06, end: 0,
                              duration: 500.ms, curve: Curves.easeOutCubic),

                  const SizedBox(height: 14),

                  // 6. Body text
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Text(
                      S.of(context).niyyahDescription,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium.copyWith(
                        color:  AppColors.neutral300,
                        height: 1.8,
                      ),
                    ),
                  )
                      .animate(delay: 1300.ms)
                      .fadeIn(duration: 500.ms),

                  const SizedBox(height: 32),

                  // 7. Intention cards
                  ...List.generate(3, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _NiyyahCard(
                        text:       _intentions(context)[i],
                        selected:   _selected == i,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selected = _selected == i ? null : i;
                            if (_selected != null) _customCtrl.clear();
                          });
                        },
                      ),
                    )
                        .animate(delay: (1500 + i * 100).ms)
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.06, end: 0,
                                duration: 400.ms, curve: Curves.easeOutCubic);
                  }),

                  const SizedBox(height: 16),

                  // 8. Custom intention field
                  Container(
                    decoration: BoxDecoration(
                      color:        AppColors.midnightMid,
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      border: Border.all(
                        color: _customCtrl.text.isNotEmpty
                            ? AppColors.goldPrimary.withOpacity(0.4)
                            : AppColors.neutral700.withOpacity(0.5),
                      ),
                    ),
                    child: TextField(
                      controller:    _customCtrl,
                      maxLines:      2,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.goldLight),
                      decoration: InputDecoration(
                        hintText:  S.of(context).writeOwnNiyyah,
                        hintStyle: AppTypography.bodyMedium.copyWith(
                          color: AppColors.goldLight.withOpacity(0.4)),
                        border:         InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      onChanged: (_) {
                        if (_selected != null) {
                          setState(() => _selected = null);
                        } else {
                          setState(() {});
                        }
                      },
                    ),
                  )
                      .animate(delay: 1900.ms)
                      .fadeIn(duration: 400.ms),

                  const SizedBox(height: 32),

                  // 9. Submit button — gold variant
                  MiskButton(
                    label:     S.of(context).declareNiyyah,
                    onPressed: _niyyah != null ? _submit : null,
                    variant:   MiskButtonVariant.gold,
                    icon:      Icons.favorite_rounded,
                  )
                      .animate(delay: 2100.ms)
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.06, end: 0,
                              duration: 400.ms, curve: Curves.easeOutCubic),

                  const SizedBox(height: 12),

                  // 10. Skip
                  MiskButton(
                    label:     S.of(context).setNiyyahLater,
                    onPressed: _submit,
                    variant:   MiskButtonVariant.ghost,
                  )
                      .animate(delay: 2200.ms)
                      .fadeIn(duration: 300.ms),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// NIYYAH CARD
// ─────────────────────────────────────────────

class _NiyyahCard extends StatelessWidget {
  const _NiyyahCard({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String   text;
  final bool     selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        transform: selected
            ? (Matrix4.identity()..scale(1.02))
            : Matrix4.identity(),
        transformAlignment: Alignment.center,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.midnightMid
              : AppColors.midnightMid,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.goldPrimary
                : AppColors.neutral700.withOpacity(0.5),
            width: selected ? 2 : 1,
          ),
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end:   Alignment.bottomRight,
                  colors: [
                    AppColors.goldPrimary.withOpacity(0.08),
                    AppColors.goldLight.withOpacity(0.04),
                  ],
                )
              : null,
        ),
        child: Row(
          children: [
            // Gold left accent bar
            Container(
              width: 3, height: 40,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.goldPrimary
                    : AppColors.goldPrimary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 14),

            // Text
            Expanded(
              child: Text(text,
                style: AppTypography.bodyMedium.copyWith(
                  color:  selected ? AppColors.goldLight : AppColors.neutral300,
                  height: 1.5,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),

            // Checkmark
            if (selected)
              Container(
                width: 24, height: 24,
                decoration: const BoxDecoration(
                  color: AppColors.goldPrimary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    size: 14, color: AppColors.midnightDeep),
              )
                  .animate()
                  .scale(begin: const Offset(0.5, 0.5),
                         end: const Offset(1, 1),
                         duration: 300.ms, curve: Curves.elasticOut),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// GOLD ORNAMENT — line with diamond centre
// ─────────────────────────────────────────────

class _GoldOrnament extends StatelessWidget {
  const _GoldOrnament();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200, height: 20,
      child: CustomPaint(painter: _OrnamentPainter()),
    );
  }
}

class _OrnamentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.goldPrimary
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = AppColors.goldPrimary
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Left line
    canvas.drawLine(
      Offset(0, cy), Offset(cx - 14, cy), paint);
    // Right line
    canvas.drawLine(
      Offset(cx + 14, cy), Offset(size.width, cy), paint);

    // Diamond centre
    final diamond = Path()
      ..moveTo(cx, cy - 6)
      ..lineTo(cx + 6, cy)
      ..lineTo(cx, cy + 6)
      ..lineTo(cx - 6, cy)
      ..close();
    canvas.drawPath(diamond, fillPaint);

    // Small dots
    canvas.drawCircle(Offset(cx - 24, cy), 2, fillPaint);
    canvas.drawCircle(Offset(cx + 24, cy), 2, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─────────────────────────────────────────────
// GEOMETRIC PATTERN — subtle octagonal grid
// ─────────────────────────────────────────────

class _GeometricPattern extends StatelessWidget {
  const _GeometricPattern();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.04,
      child: SizedBox.expand(
        child: CustomPaint(painter: _PatternPainter()),
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.goldPrimary
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    const spacing = 60.0;
    const r = 20.0;

    for (double x = 0; x < size.width + spacing; x += spacing) {
      for (double y = 0; y < size.height + spacing; y += spacing) {
        // Octagon
        final path = Path();
        for (int i = 0; i < 8; i++) {
          final angle = (i * math.pi / 4) - math.pi / 8;
          final px = x + r * math.cos(angle);
          final py = y + r * math.sin(angle);
          if (i == 0) {
            path.moveTo(px, py);
          } else {
            path.lineTo(px, py);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
