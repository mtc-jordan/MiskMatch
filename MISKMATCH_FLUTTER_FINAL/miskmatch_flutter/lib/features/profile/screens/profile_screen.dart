import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/profile_provider.dart';
import 'package:miskmatch/features/discovery/widgets/voice_player.dart';
import 'package:miskmatch/core/router/app_router.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/shared/widgets/common_widgets.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileProvider);
    final completion   = ref.watch(profileCompletionProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, ref),
          SliverToBoxAdapter(
            child: switch (profileState) {
              ProfileLoading() || ProfileInitial() => const _ProfileShimmer(),
              ProfileError(error: final e) => _ProfileErrorState(
                  message: e.message,
                  onRetry: () => ref.read(profileProvider.notifier).load()),
              ProfileLoaded(profile: final p) ||
              ProfileSaving(profile: final p) => Column(
                  children: [
                    _ProfileHeader(profile: p),
                    _CompletionCard(completion: completion),
                    _IslamicSignalsSection(profile: p),
                    _LifeGoalsSection(profile: p),
                    _BioSection(profile: p),
                    const SizedBox(height: AppSpacing.bottomNavHeight + 16),
                  ],
                ),
              _ => const _ProfileShimmer(),
            },
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, WidgetRef ref) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      title: Text('My Profile',
          style: AppTypography.titleLarge.copyWith(
            color: AppColors.roseDeep, fontWeight: FontWeight.w700)),
      actions: [
        TextButton.icon(
          onPressed: () => context.push(AppRoutes.profileEdit),
          icon:  const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Edit'),
          style: TextButton.styleFrom(foregroundColor: AppColors.roseDeep),
        ),
        IconButton(
          icon:    const Icon(Icons.settings_outlined),
          color:   AppColors.neutral500,
          onPressed: () => context.push(AppRoutes.settings),
          tooltip: 'Settings',
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// PROFILE HEADER
// ─────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});
  final dynamic profile; // UserProfile

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Avatar
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  gradient:   AppColors.roseGradient,
                  shape:      BoxShape.circle,
                  boxShadow:  AppShadows.elevated,
                ),
                child: Center(
                  child: Text(
                    profile.firstName.isNotEmpty
                        ? profile.firstName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 44, color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Container(
                width: 32, height: 32,
                decoration: const BoxDecoration(
                  color:  AppColors.white,
                  shape:  BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 4)
                  ],
                ),
                child: const Icon(Icons.camera_alt_outlined,
                    size: 16, color: AppColors.roseDeep),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Text(
            '${profile.firstName} ${profile.lastNameInitial}',
            style: AppTypography.headlineMedium.copyWith(
              color: AppColors.neutral900),
          ),

          if (profile.locationText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 14, color: AppColors.neutral500),
                const SizedBox(width: 3),
                Text(profile.locationText,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.neutral500)),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // Trust badges
          Wrap(
            spacing: 8, runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              if (profile.mosqueVerified)
                const TrustBadge(type: TrustBadgeType.mosque),
              if (profile.scholarEndorsed)
                const TrustBadge(type: TrustBadgeType.scholar),
              if (profile.idVerified)
                const TrustBadge(type: TrustBadgeType.identity),
            ],
          ),

          if (profile.hasVoiceIntro) ...[
            const SizedBox(height: 16),
            VoicePlayerWidget(
              audioUrl: profile.voiceIntroUrl!,
              label:    'My voice intro',
            ),
          ],

          const SizedBox(height: 20),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.05, end: 0);
  }
}

// ─────────────────────────────────────────────
// COMPLETION CARD
// ─────────────────────────────────────────────

class _CompletionCard extends StatelessWidget {
  const _CompletionCard({required this.completion});
  final AsyncValue<dynamic> completion;

  @override
  Widget build(BuildContext context) {
    return completion.when(
      loading: () => const SizedBox.shrink(),
      error:   (_, __) => const SizedBox.shrink(),
      data: (c) {
        if (c.percentage >= 95) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppColors.roseDeep.withOpacity(0.06),
              AppColors.goldPrimary.withOpacity(0.04),
            ]),
            borderRadius: AppRadius.cardRadius,
            border: Border.all(
              color: AppColors.roseDeep.withOpacity(0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Profile strength',
                      style: AppTypography.titleSmall.copyWith(
                        color: AppColors.roseDeep)),
                  const Spacer(),
                  Text('${c.percentage}%',
                      style: AppTypography.titleSmall.copyWith(
                        color: AppColors.roseDeep,
                        fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value:           c.percentage / 100,
                  backgroundColor: AppColors.roseLight.withOpacity(0.3),
                  valueColor: const AlwaysStoppedAnimation(AppColors.roseDeep),
                  minHeight: 6,
                ),
              ),
              if (c.missingFields.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Add: ${c.missingFields.take(3).join(', ')}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.neutral500),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// ISLAMIC SIGNALS SECTION
// ─────────────────────────────────────────────

class _IslamicSignalsSection extends StatelessWidget {
  const _IslamicSignalsSection({required this.profile});
  final dynamic profile;

  @override
  Widget build(BuildContext context) {
    final items = <(String, String, String)>[];
    if (profile.prayerFrequency != null)
      items.add(('Prayer', profile.prayerFrequency.emoji, profile.prayerLabel));
    if (profile.madhab != null)
      items.add(('Madhab', '📚', profile.madhabLabel));
    if (profile.quranLevel != null && profile.quranLevel!.isNotEmpty)
      items.add(('Quran', '📖', profile.quranLevel));
    if (profile.hijabStance != null && profile.hijabStance!.value != 'na')
      items.add(('Hijab', '🧕', profile.hijabLabel));

    if (items.isEmpty) return const SizedBox.shrink();

    return _Section(
      title: 'Islamic Practice',
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 3.2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          padding: EdgeInsets.zero,
          children: items.map((item) {
            final (label, emoji, value) = item;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.roseDeep.withOpacity(0.04),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.roseDeep.withOpacity(0.1)),
              ),
              child: Row(children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(label,
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.neutral500, fontSize: 10)),
                      Text(value,
                          style: AppTypography.labelMedium.copyWith(
                            color: AppColors.neutral800),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ]),
            );
          }).toList(),
        ),
      ],
    );
  }
}

extension on AppColors {
  static const neutral800 = Color(0xFF2D2D4E);
}

// ─────────────────────────────────────────────
// LIFE GOALS SECTION
// ─────────────────────────────────────────────

class _LifeGoalsSection extends StatelessWidget {
  const _LifeGoalsSection({required this.profile});
  final dynamic profile;

  @override
  Widget build(BuildContext context) {
    final goals = <String>[];
    if (profile.wantsChildren == true)
      goals.add('👶 Wants ${profile.numChildrenDesired ?? ''} children'.trim());
    if (profile.hajjTimeline != null) goals.add('🕋 ${profile.hajjTimeline}');
    if (profile.islamicFinanceStance == 'strict')
      goals.add('💚 Islamic finance only');
    if (profile.wantsHijra) goals.add('✈️ Wants hijra');

    if (goals.isEmpty) return const SizedBox.shrink();

    return _Section(
      title: 'Life Goals',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: goals.map((g) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.6),
              borderRadius: AppRadius.chipRadius,
            ),
            child: Text(g,
                style: AppTypography.labelSmall.copyWith(
                  color: Theme.of(context).colorScheme.primary)),
          )).toList(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// BIO SECTION
// ─────────────────────────────────────────────

class _BioSection extends StatelessWidget {
  const _BioSection({required this.profile});
  final dynamic profile;

  @override
  Widget build(BuildContext context) {
    final bio = profile.bio as String?;
    if (bio == null || bio.isEmpty) return const SizedBox.shrink();
    return _Section(
      title: 'About me',
      children: [
        Text(bio,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.neutral700, height: 1.6)),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// SECTION WRAPPER
// ─────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String       title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: AppTypography.titleSmall.copyWith(
                color: AppColors.neutral700)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.03, end: 0);
  }
}

// ─────────────────────────────────────────────
// LOADING / ERROR STATES
// ─────────────────────────────────────────────

class _ProfileShimmer extends StatelessWidget {
  const _ProfileShimmer();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(40),
      child: Center(child: CircularProgressIndicator(
          color: AppColors.roseDeep, strokeWidth: 2)),
    );
  }
}

class _ProfileErrorState extends StatelessWidget {
  const _ProfileErrorState({required this.message, required this.onRetry});
  final String       message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.neutral500)),
          const SizedBox(height: 24),
          MiskButton(
            label:     'Try again',
            onPressed: onRetry,
            variant:   MiskButtonVariant.outline,
            fullWidth: false,
          ),
        ],
      ),
    );
  }
}
