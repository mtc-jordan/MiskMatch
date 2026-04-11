import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../providers/profile_provider.dart';
import 'package:miskmatch/features/discovery/widgets/voice_player.dart';
import 'package:miskmatch/core/router/app_router.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/shared/widgets/common_widgets.dart';
import 'package:miskmatch/shared/models/api_response.dart';
import 'package:miskmatch/features/profile/data/profile_models.dart';
import 'package:miskmatch/l10n/generated/app_localizations.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileProvider);
    final completion   = ref.watch(profileCompletionProvider);

    return Scaffold(
      backgroundColor: context.scaffoldColor,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, ref),
          SliverToBoxAdapter(
            child: switch (profileState) {
              ProfileLoading() || ProfileInitial() => const _ProfileShimmer(),
              ProfileError(error: final e) => e.type == AppErrorType.notFound
                  ? _CreateProfilePrompt(
                      onTap: () => context.push(AppRoutes.profileEdit))
                  : _ProfileErrorState(
                      message: e.message,
                      onRetry: () =>
                          ref.read(profileProvider.notifier).load()),
              ProfileLoaded(profile: final p) ||
              ProfileSaving(profile: final p) => _ProfileContent(
                  profile:    p,
                  completion: completion,
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
      backgroundColor: context.scaffoldColor,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      title: Text(S.of(context).myProfile,
        style: const TextStyle(
          fontFamily:  'Georgia',
          fontSize:    22,
          fontWeight:  FontWeight.w700,
          color:       AppColors.roseDeep,
        ),
      ),
      actions: [
        IconButton(
          icon:    const Icon(Icons.edit_outlined, size: 20),
          color:   AppColors.roseDeep,
          onPressed: () => context.push(AppRoutes.profileEdit),
          tooltip: S.of(context).editProfile,
        ),
        IconButton(
          icon:    const Icon(Icons.settings_outlined, size: 20),
          color:   context.mutedText,
          onPressed: () => context.push(AppRoutes.settings),
          tooltip: S.of(context).settings,
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// PROFILE CONTENT — all sections
// ─────────────────────────────────────────────

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({
    required this.profile,
    required this.completion,
  });
  final UserProfile                   profile;
  final AsyncValue<ProfileCompletion> completion;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _HeroSection(profile: profile),
        _ProfileStrengthBar(completion: completion),
        if (profile.hasVoiceIntro) _VoiceIntroCard(profile: profile),
        _IslamicPracticeGrid(profile: profile),
        _LifeGoalsChips(profile: profile),
        _BioSection(profile: profile),
        _StatsRow(profile: profile),
        const SizedBox(height: AppSpacing.bottomNavHeight + 24),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// HERO SECTION — avatar, name, location, badges
// ─────────────────────────────────────────────

class _HeroSection extends ConsumerWidget {
  const _HeroSection({required this.profile});
  final UserProfile profile;

  Future<void> _pickAndUploadPhoto(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();

    // Show source picker bottom sheet
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(S.of(context).updateProfilePhoto,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.roseDeep),
              title: Text(S.of(context).takePhoto),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.roseDeep),
              title: Text(S.of(context).chooseFromGallery),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );

    if (pickedFile == null) return;

    // Crop to square
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Photo',
          toolbarColor: AppColors.roseDeep,
          toolbarWidgetColor: AppColors.white,
          activeControlsWidgetColor: AppColors.roseDeep,
        ),
        IOSUiSettings(title: 'Crop Photo'),
      ],
    );

    if (croppedFile == null) return;

    final file = File(croppedFile.path);
    final success = await ref.read(profileProvider.notifier).uploadPhoto(file);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
            ? S.of(context).photoUpdated
            : S.of(context).photoUploadFailed),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        children: [
          // ── 100px avatar with camera overlay ──────────────────
          GestureDetector(
            onTap: () => _pickAndUploadPhoto(context, ref),
            onLongPress: () => _pickAndUploadPhoto(context, ref),
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    gradient: AppColors.roseGradient,
                    shape:    BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:      AppColors.roseDeep.withOpacity(0.25),
                        blurRadius: 20,
                        offset:     const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      profile.firstName.isNotEmpty
                          ? profile.firstName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize:   44,
                        color:      AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
                    .animate()
                    .scale(begin: const Offset(0.8, 0.8),
                           end: const Offset(1.0, 1.0),
                           duration: 500.ms,
                           curve: Curves.elasticOut),

                // Camera overlay bottom-right
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color:  context.surfaceColor,
                    shape:  BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:      Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Icon(Icons.camera_alt_outlined,
                      size: 16, color: AppColors.roseDeep),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Name + last initial ─────────────────────────────
          Text(
            '${profile.firstName} ${profile.lastNameInitial}',
            style: TextStyle(
              fontFamily:  'Georgia',
              fontSize:    28,
              fontWeight:  FontWeight.w700,
              color:       context.onSurface,
            ),
          )
              .animate(delay: 100.ms)
              .fadeIn(duration: 400.ms),

          // ── Location ────────────────────────────────────────
          if (profile.locationText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(profile.locationText,
              style: AppTypography.bodySmall.copyWith(
                color:    context.mutedText,
                fontSize: 13,
              ),
            ),
          ],

          // ── Trust badges ────────────────────────────────────
          const SizedBox(height: 12),
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

          // ── Member since ────────────────────────────────────
          const SizedBox(height: 10),
          Text(
            'Member since ${_memberDate(profile)}',
            style: AppTypography.labelSmall.copyWith(
              color:    AppColors.goldPrimary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  String _memberDate(UserProfile p) {
    // Use created date if available, fallback to current
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final now = DateTime.now();
    return '${months[now.month]} ${now.year}';
  }
}

// ─────────────────────────────────────────────
// PROFILE STRENGTH BAR — gold gradient card
// ─────────────────────────────────────────────

class _ProfileStrengthBar extends StatelessWidget {
  const _ProfileStrengthBar({required this.completion});
  final AsyncValue<ProfileCompletion> completion;

  @override
  Widget build(BuildContext context) {
    return completion.when(
      loading: () => const SizedBox.shrink(),
      error:   (_, __) => const SizedBox.shrink(),
      data: (c) {
        if (c.percentage >= 100) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppColors.goldPrimary.withOpacity(0.12),
              AppColors.goldLight.withOpacity(0.08),
            ]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.goldPrimary.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(S.of(context).profileStrength,
                    style: AppTypography.titleSmall.copyWith(
                      color: AppColors.goldDark,
                    ),
                  ),
                  const Spacer(),
                  Text('${c.percentage}%',
                    style: TextStyle(
                      fontFamily:  'Georgia',
                      fontSize:    18,
                      fontWeight:  FontWeight.w700,
                      color:       AppColors.roseDeep,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: TweenAnimationBuilder<double>(
                  tween:    Tween(begin: 0, end: c.percentage / 100),
                  duration: 600.ms,
                  curve:    Curves.easeOutCubic,
                  builder: (_, value, __) => LinearProgressIndicator(
                    value:           value,
                    backgroundColor: AppColors.goldPrimary.withOpacity(0.15),
                    valueColor: const AlwaysStoppedAnimation(AppColors.roseDeep),
                    minHeight: 6,
                  ),
                ),
              ),
              if (c.missingFields.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Add: ${c.missingFields.take(3).join(', ')}',
                  style: AppTypography.caption.copyWith(
                    color:    context.mutedText,
                    fontSize: 9,
                  ),
                ),
              ],
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 400.ms)
            .slideY(begin: 0.05, end: 0, duration: 400.ms);
      },
    );
  }
}

// ─────────────────────────────────────────────
// VOICE INTRO CARD — gold border variant
// ─────────────────────────────────────────────

class _VoiceIntroCard extends StatelessWidget {
  const _VoiceIntroCard({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.goldPrimary.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: VoicePlayerWidget(
        audioUrl: profile.voiceIntroUrl!,
        label:    S.of(context).myVoiceIntro,
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms);
  }
}

// ─────────────────────────────────────────────
// ISLAMIC PRACTICE GRID — 2 columns
// ─────────────────────────────────────────────

class _IslamicPracticeGrid extends StatelessWidget {
  const _IslamicPracticeGrid({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final items = <(String, String, String)>[];
    if (profile.prayerFrequency != null) {
      items.add(('Prayer', profile.prayerFrequency!.emoji,
          profile.prayerFrequency!.label));
    }
    if (profile.madhab != null) {
      items.add(('Madhab', '📚', profile.madhab!.label));
    }
    if (profile.quranLevel != null && profile.quranLevel!.isNotEmpty) {
      items.add(('Quran', '📖', profile.quranLevel!));
    }
    if (profile.hijabStance != null && profile.hijabStance!.value != 'na') {
      items.add(('Hijab', '🧕', profile.hijabStance!.label));
    }
    if (profile.isRevert) {
      items.add(('Revert', '🌙', profile.revertYear != null
          ? 'Since ${profile.revertYear}'
          : 'Yes'));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return _Section(
      title: S.of(context).islamicPractice,
      child: GridView.count(
        crossAxisCount:  2,
        shrinkWrap:      true,
        physics:         const NeverScrollableScrollPhysics(),
        childAspectRatio: 3.0,
        mainAxisSpacing:  8,
        crossAxisSpacing: 8,
        padding:         EdgeInsets.zero,
        children: items.map((item) {
          final (label, emoji, value) = item;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color:        context.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color:      AppColors.roseDeep.withOpacity(0.04),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Row(
              children: [
                // Rose left accent 3px
                Container(
                  width: 3, height: 32,
                  decoration: BoxDecoration(
                    color:        AppColors.roseDeep.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment:  MainAxisAlignment.center,
                    children: [
                      Text(label,
                        style: AppTypography.caption.copyWith(
                          color:    context.mutedText,
                          fontSize: 9,
                        ),
                      ),
                      Text('$emoji $value',
                        style: AppTypography.labelMedium.copyWith(
                          color:      context.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// LIFE GOALS CHIPS — horizontal scroll
// ─────────────────────────────────────────────

class _LifeGoalsChips extends StatelessWidget {
  const _LifeGoalsChips({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final goals = <String>[];
    if (profile.wantsChildren == true) {
      goals.add('👶 Wants ${profile.numChildrenDesired ?? ''} children'.trim());
    } else if (profile.wantsChildren == false) {
      goals.add('👶 No children');
    }
    if (profile.hajjTimeline != null) {
      final hajjLabels = {
        'within_1_year':  '🕋 Hajj this year',
        'within_3_years': '🕋 Hajj within 3y',
        'within_5_years': '🕋 Hajj within 5y',
        'someday':        '🕋 Hajj someday',
        'done':           '🕋 Hajj done',
      };
      goals.add(hajjLabels[profile.hajjTimeline] ??
          '🕋 ${profile.hajjTimeline}');
    }
    if (profile.islamicFinanceStance == 'strict') {
      goals.add('💚 Islamic finance only');
    }
    if (profile.wantsHijra) {
      goals.add('✈️ Wants hijra${profile.hijraCountry != null
          ? ' to ${profile.hijraCountry}' : ''}');
    }

    if (goals.isEmpty) return const SizedBox.shrink();

    return _Section(
      title: S.of(context).lifeGoals,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: goals.map((g) {
            return Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color:        AppColors.roseLight,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(g,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.roseDeep,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// BIO SECTION — expandable
// ─────────────────────────────────────────────

class _BioSection extends StatefulWidget {
  const _BioSection({required this.profile});
  final UserProfile profile;

  @override
  State<_BioSection> createState() => _BioSectionState();
}

class _BioSectionState extends State<_BioSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final bio = widget.profile.bio;
    if (bio == null || bio.isEmpty) return const SizedBox.shrink();

    return _Section(
      title: S.of(context).aboutMe,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(bio,
            maxLines:  _expanded ? null : 3,
            overflow:  _expanded
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
            style: AppTypography.bodyMedium.copyWith(
              color:  context.subtleText,
              height: 1.6,
            ),
          ),
          if (bio.length > 120)
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _expanded ? S.of(context).showLess : S.of(context).readMore,
                  style: AppTypography.labelSmall.copyWith(
                    color:      AppColors.roseDeep,
                    fontSize:   11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// STATS ROW
// ─────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    // Show if profile has any stats data
    // Placeholder — will populate when game history is available
    return const SizedBox.shrink();
  }
}

// ─────────────────────────────────────────────
// SECTION WRAPPER
// ─────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
            style: AppTypography.titleSmall.copyWith(
              color:      context.subtleText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    ).animate().fadeIn(duration: 400.ms)
        .slideY(begin: 0.03, end: 0, duration: 400.ms);
  }
}

// ─────────────────────────────────────────────
// LOADING / ERROR / CREATE STATES
// ─────────────────────────────────────────────

class _ProfileShimmer extends StatelessWidget {
  const _ProfileShimmer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        children: [
          // Avatar placeholder
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              color: context.subtleBg,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 20),
          // Name bar
          Container(
            width: 180, height: 20,
            decoration: BoxDecoration(
              color: context.subtleBg,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 12),
          // Subtitle bar
          Container(
            width: 120, height: 14,
            decoration: BoxDecoration(
              color: context.subtleBg,
              borderRadius: BorderRadius.circular(7),
            ),
          ),
          const SizedBox(height: 24),
          // Card placeholders
          ...List.generate(3, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                color: context.subtleBg,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          )),
        ],
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(
          duration: 1200.ms,
          color:    Colors.white.withOpacity(0.4),
        );
  }
}

class _CreateProfilePrompt extends StatelessWidget {
  const _CreateProfilePrompt({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppColors.roseDeep.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_add_alt_1_rounded,
                size: 36, color: AppColors.roseDeep),
          ),
          const SizedBox(height: 20),
          Text(S.of(context).completeYourProfile,
            style: AppTypography.titleLarge.copyWith(
              color: context.onSurface, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            S.of(context).completeProfileHint,
            style: AppTypography.bodyMedium.copyWith(
              color: context.mutedText, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          MiskButton(
            label:     S.of(context).setUpMyProfile,
            onPressed: onTap,
            icon:      Icons.arrow_forward_rounded,
          ),
        ],
      ),
    );
  }
}

class _ProfileErrorState extends StatelessWidget {
  const _ProfileErrorState({
    required this.message,
    required this.onRetry,
  });
  final String       message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 48, color: AppColors.neutral300),
          const SizedBox(height: 16),
          Text(message,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: context.mutedText),
          ),
          const SizedBox(height: 24),
          MiskButton(
            label:     S.of(context).tryAgain,
            onPressed: onRetry,
            variant:   MiskButtonVariant.outline,
            fullWidth: false,
          ),
        ],
      ),
    );
  }
}
