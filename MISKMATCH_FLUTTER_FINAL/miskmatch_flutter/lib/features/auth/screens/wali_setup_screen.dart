import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:miskmatch/core/router/app_router.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/shared/widgets/common_widgets.dart';

/// Wali (guardian) setup screen — step 2 of onboarding.
/// Collects guardian's name, phone, and relationship.
/// Optional: user can skip and add wali later from settings.

class WaliSetupScreen extends ConsumerStatefulWidget {
  const WaliSetupScreen({super.key});

  @override
  ConsumerState<WaliSetupScreen> createState() => _WaliSetupScreenState();
}

class _WaliSetupScreenState extends ConsumerState<WaliSetupScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _nameCtrl     = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  String _relationship= 'father';
  bool   _loading     = false;

  static const _relationships = [
    ('father',              'Father',               'والد',   Icons.man_rounded),
    ('brother',             'Brother',              'أخ',     Icons.person_rounded),
    ('uncle',               'Uncle',                'عم',     Icons.elderly_rounded),
    ('grandfather',         'Grandfather',          'جد',     Icons.elderly_rounded),
    ('male_relative',       'Male Relative',        'قريب',   Icons.group_rounded),
    ('imam',                'Imam',                 'إمام',   Icons.mosque_rounded),
    ('trusted_male_guardian','Trusted Guardian',    'وليّ',   Icons.shield_rounded),
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    // TODO: call wali service API
    await Future.delayed(const Duration(seconds: 1)); // simulate API

    setState(() => _loading = false);
    if (mounted) context.go(AppRoutes.discovery);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LoadingOverlay(
      isLoading: _loading,
      child: Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // ── Header ───────────────────────────────────────────
                  _WaliHeader()
                      .animate()
                      .fadeIn(duration: 500.ms)
                      .slideY(begin: -0.05, end: 0),

                  const SizedBox(height: 28),

                  // ── Guardian name ─────────────────────────────────────
                  Text('Guardian\'s full name',
                      style: AppTypography.titleSmall)
                      .animate(delay: 100.ms).fadeIn(),

                  const SizedBox(height: 10),
                  MiskTextField(
                    label:      'Guardian name',
                    hint:       'e.g. Ahmad Al-Rashidi',
                    controller: _nameCtrl,
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.trim().length < 2) {
                        return 'Please enter the guardian\'s full name';
                      }
                      return null;
                    },
                  )
                      .animate(delay: 150.ms)
                      .fadeIn(duration: 400.ms)
                      .slideX(begin: -0.05, end: 0),

                  const SizedBox(height: 16),

                  // ── Guardian phone ────────────────────────────────────
                  Text('Guardian\'s phone number',
                      style: AppTypography.titleSmall)
                      .animate(delay: 200.ms).fadeIn(),

                  const SizedBox(height: 10),
                  MiskTextField(
                    label:        'Phone with country code',
                    hint:         '+962 7X XXX XXXX',
                    controller:   _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    prefixIcon:   const Icon(Icons.phone_outlined),
                    textInputAction: TextInputAction.done,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter the guardian\'s phone number';
                      }
                      if (!RegExp(r'^\+\d{7,15}$').hasMatch(v.trim())) {
                        return 'Enter number with country code, e.g. +962791234567';
                      }
                      return null;
                    },
                  )
                      .animate(delay: 250.ms)
                      .fadeIn(duration: 400.ms)
                      .slideX(begin: -0.05, end: 0),

                  const SizedBox(height: 24),

                  // ── Relationship picker ───────────────────────────────
                  Text('Relationship', style: AppTypography.titleSmall)
                      .animate(delay: 300.ms).fadeIn(),

                  const SizedBox(height: 12),
                  _RelationshipPicker(
                    relationships:    _relationships,
                    selected:         _relationship,
                    onSelect:         (r) => setState(() => _relationship = r),
                  )
                      .animate(delay: 350.ms)
                      .fadeIn(duration: 400.ms),

                  const SizedBox(height: 28),

                  // ── What happens next ────────────────────────────────
                  _WaliInfoCard()
                      .animate(delay: 400.ms)
                      .fadeIn(duration: 400.ms),

                  const SizedBox(height: 28),

                  // ── Submit ────────────────────────────────────────────
                  MiskButton(
                    label:     'Set up guardian & continue',
                    onPressed: _submit,
                    loading:   _loading,
                    icon:      Icons.shield_rounded,
                  )
                      .animate(delay: 500.ms)
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 12),

                  MiskButton(
                    label:     'Skip — set up guardian later',
                    onPressed: () => context.go(AppRoutes.discovery),
                    variant:   MiskButtonVariant.ghost,
                  )
                      .animate(delay: 550.ms)
                      .fadeIn(),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SUB-WIDGETS
// ─────────────────────────────────────────────

class _WaliHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color:        AppColors.goldPrimary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.shield_rounded,
              color: AppColors.goldPrimary, size: 28),
        ),
        const SizedBox(height: 16),
        Text('Set up your Wali',
            style: AppTypography.headlineSmall.copyWith(
              color: AppColors.neutral900,
            )),
        const SizedBox(height: 8),
        Text(
          'Islam requires a guardian (wali) for a woman\'s marriage. '
          'Your wali will be notified of matches and can approve or '
          'decline them. Their involvement is a barakah, not a barrier.',
          style: AppTypography.bodyMedium.copyWith(
            color:  AppColors.neutral500,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

class _RelationshipPicker extends StatelessWidget {
  const _RelationshipPicker({
    required this.relationships,
    required this.selected,
    required this.onSelect,
  });

  final List<(String, String, String, IconData)> relationships;
  final String                                    selected;
  final void Function(String)                     onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: relationships.map((r) {
        final (key, label, labelAr, icon) = r;
        final isSelected = selected == key;
        return GestureDetector(
          onTap: () => onSelect(key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color:        isSelected
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surface,
              borderRadius: AppRadius.chipRadius,
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size:  16,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : AppColors.neutral500),
                const SizedBox(width: 7),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: AppTypography.labelMedium.copyWith(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : AppColors.neutral700,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        )),
                    Text(labelAr,
                        style: TextStyle(
                          fontFamily: 'Scheherazade',
                          fontSize:   11,
                          color: isSelected
                              ? theme.colorScheme.primary.withOpacity(0.7)
                              : AppColors.neutral500,
                        )),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _WaliInfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MiskCard(
      color: AppColors.goldPrimary.withOpacity(0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: AppColors.goldPrimary, size: 18),
              const SizedBox(width: 8),
              Text('What happens next?',
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.goldDark,
                  )),
            ],
          ),
          const SizedBox(height: 12),
          ...[
            '📱 Your guardian receives an SMS invitation',
            '✅ They accept — you\'re ready to receive matches',
            '🤲 They approve or decline each match you receive',
            '💬 They can optionally view your chaperoned conversations',
          ].map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(s,
                style: AppTypography.bodySmall.copyWith(
                  color:  AppColors.neutral700,
                  height: 1.5,
                )),
          )),
        ],
      ),
    );
  }
}
