import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:miskmatch/features/profile/data/profile_models.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/shared/widgets/common_widgets.dart';
import 'voice_player.dart';

/// The core discovery profile card.
///
/// Design: Hinge-style (not Tinder swipe) — a rich scrollable card
/// that reveals Islamic character signals progressively.
///
/// Layout:
///   1. Photo / avatar header (full-width, blurred if not yet mutual)
///   2. Name, age, location, trust badges
///   3. Voice intro playback (60s)
///   4. Islamic practice row (prayer, madhab, quran)
///   5. Life goals chips
///   6. Bio snippet (max 3 lines, expandable)
///   7. Compatibility ring + score breakdown
///   8. Express interest CTA

class ProfileCard extends StatefulWidget {
  const ProfileCard({
    super.key,
    required this.candidate,
    required this.onInterest,
    required this.onDismiss,
    required this.onExpand,
    this.index = 0,
  });

  final CandidateCard     candidate;
  final VoidCallback       onInterest;
  final VoidCallback       onDismiss;
  final VoidCallback       onExpand;    // open full profile detail
  final int                index;

  @override
  State<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard> {
  bool _bioExpanded = false;

  UserProfile get profile => widget.candidate.profile;
  double      get score   => widget.candidate.compatibilityScore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding, vertical: 8),
      decoration: BoxDecoration(
        color:        theme.colorScheme.surface,
        borderRadius: AppRadius.cardRadius,
        boxShadow:    AppShadows.card,
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Photo header ─────────────────────────────────────────
          _PhotoHeader(profile: profile, onExpand: widget.onExpand),

          Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 2. Name + location + trust ───────────────────────
                _NameRow(profile: profile, score: score),

                const SizedBox(height: 12),

                // ── 3. Voice intro ───────────────────────────────────
                if (profile.hasVoiceIntro) ...[
                  VoicePlayerWidget(
                    audioUrl: profile.voiceIntroUrl!,
                    label:    'Hear ${profile.displayFirstName}\'s intro',
                  ),
                  const SizedBox(height: 14),
                ],

                // ── 4. Islamic practice signals ──────────────────────
                _IslamicPracticeRow(profile: profile),

                const SizedBox(height: 12),

                // ── 5. Life goals chips ──────────────────────────────
                _LifeGoalsChips(profile: profile),

                const SizedBox(height: 14),

                // ── 6. Bio ───────────────────────────────────────────
                if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                  _BioSection(
                    bio:         profile.bio!,
                    expanded:    _bioExpanded,
                    onToggle:    () =>
                        setState(() => _bioExpanded = !_bioExpanded),
                  ),
                  const SizedBox(height: 14),
                ],

                // ── 7. Compatibility breakdown ────────────────────────
                _CompatibilitySection(candidate: widget.candidate),

                const SizedBox(height: 16),

                // ── 8. Action buttons ─────────────────────────────────
                _ActionRow(
                  onInterest: widget.onInterest,
                  onDismiss:  widget.onDismiss,
                  onExpand:   widget.onExpand,
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate(delay: Duration(milliseconds: widget.index * 80))
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.06, end: 0, duration: 400.ms, curve: Curves.easeOut);
  }
}

// ─────────────────────────────────────────────
// PHOTO HEADER
// ─────────────────────────────────────────────

class _PhotoHeader extends StatelessWidget {
  const _PhotoHeader({required this.profile, required this.onExpand});
  final UserProfile  profile;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onExpand,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl)),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: profile.hasPhoto && profile.photoUrl != null
              ? CachedNetworkImage(
                  imageUrl:   profile.photoUrl!,
                  fit:        BoxFit.cover,
                  placeholder: (_, __) => _PhotoPlaceholder(profile: profile),
                  errorWidget: (_, __, ___) =>
                      _PhotoPlaceholder(profile: profile),
                )
              : _PhotoPlaceholder(profile: profile),
        ),
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.roseLight.withOpacity(0.3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              gradient: AppColors.roseGradient,
              shape:    BoxShape.circle,
            ),
            child: Center(
              child: Text(
                profile.firstName.isNotEmpty
                    ? profile.firstName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontSize:   32,
                  color:      AppColors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Photo revealed after mutual interest',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.neutral500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// NAME ROW
// ─────────────────────────────────────────────

class _NameRow extends StatelessWidget {
  const _NameRow({required this.profile, required this.score});
  final UserProfile profile;
  final double      score;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name + age
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: profile.displayFirstName,
                      style: AppTypography.titleLarge.copyWith(
                        color:      AppColors.neutral900,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (profile.age != null)
                      TextSpan(
                        text: ', ${profile.age}',
                        style: AppTypography.titleLarge.copyWith(
                          color: AppColors.neutral500,
                        ),
                      ),
                  ],
                ),
              ),
              // Location
              if (profile.locationText.isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: AppColors.neutral500),
                    const SizedBox(width: 3),
                    Text(profile.locationText,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.neutral500,
                        )),
                  ],
                ),
              ],
              // Trust badges
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (profile.mosqueVerified)
                    const TrustBadge(type: TrustBadgeType.mosque),
                  if (profile.scholarEndorsed)
                    const TrustBadge(type: TrustBadgeType.scholar),
                  if (profile.idVerified)
                    const TrustBadge(type: TrustBadgeType.identity),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Compatibility ring
        if (score > 0)
          CompatibilityRing(score: score, size: 64),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// ISLAMIC PRACTICE ROW
// ─────────────────────────────────────────────

class _IslamicPracticeRow extends StatelessWidget {
  const _IslamicPracticeRow({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final items = <(String, String)>[];

    if (profile.prayerFrequency != null) {
      items.add((
        profile.prayerFrequency!.emoji,
        profile.prayerFrequency!.label,
      ));
    }
    if (profile.madhab != null) {
      items.add(('📚', profile.madhab!.label));
    }
    if (profile.quranLevel != null && profile.quranLevel!.isNotEmpty) {
      final quranLabels = {
        'hafiz':           'Hafiz 📖',
        'hafiz_partial':   'Partial Hafiz 📖',
        'memorising':      'Memorising Quran',
        'recites_tajweed': 'Tajweed recitation',
        'strong':          'Strong recitation',
        'learning':        'Learning Quran',
        'beginner':        'Quran beginner',
      };
      items.add(('📖', quranLabels[profile.quranLevel] ?? profile.quranLevel!));
    }
    if (profile.isRevert) {
      items.add(('🌙', profile.revertYear != null
          ? 'Revert since ${profile.revertYear}'
          : 'Revert'));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.roseDeep.withOpacity(0.04),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.roseDeep.withOpacity(0.1),
        ),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: items.map((item) {
          final (emoji, label) = item;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 5),
              Text(label,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.neutral700,
                    fontWeight: FontWeight.w500,
                  )),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// LIFE GOALS CHIPS
// ─────────────────────────────────────────────

class _LifeGoalsChips extends StatelessWidget {
  const _LifeGoalsChips({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final chips = <String>[];

    if (profile.wantsChildren == true) {
      chips.add(profile.numChildrenDesired != null
          ? '👶 Wants ${profile.numChildrenDesired} children'
          : '👶 Wants children');
    } else if (profile.wantsChildren == false) {
      chips.add('No children');
    }

    if (profile.hajjTimeline != null) {
      final hajjLabels = {
        'within_1_year':  '🕋 Hajj this year',
        'within_3_years': '🕋 Hajj within 3 years',
        'within_5_years': '🕋 Hajj within 5 years',
        'someday':        '🕋 Hajj someday',
        'done':           '🕋 Hajj done',
      };
      final label = hajjLabels[profile.hajjTimeline];
      if (label != null) chips.add(label);
    }

    if (profile.islamicFinanceStance == 'strict') {
      chips.add('💚 Islamic finance only');
    }
    if (profile.wantsHijra) {
      chips.add('✈️ Wants hijra${profile.hijraCountry != null ? ' to ${profile.hijraCountry}' : ''}');
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: chips
          .map((chip) => _GoalChip(label: chip))
          .toList(),
    );
  }
}

class _GoalChip extends StatelessWidget {
  const _GoalChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color:        Theme.of(context).colorScheme.primaryContainer
            .withOpacity(0.6),
        borderRadius: AppRadius.chipRadius,
      ),
      child: Text(label,
          style: AppTypography.labelSmall.copyWith(
            color: Theme.of(context).colorScheme.primary,
          )),
    );
  }
}

// ─────────────────────────────────────────────
// BIO SECTION
// ─────────────────────────────────────────────

class _BioSection extends StatelessWidget {
  const _BioSection({
    required this.bio,
    required this.expanded,
    required this.onToggle,
  });
  final String       bio;
  final bool         expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          bio,
          maxLines:       expanded ? null : 3,
          overflow:       expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: AppTypography.bodyMedium.copyWith(
            color:  AppColors.neutral700,
            height: 1.6,
          ),
        ),
        if (bio.length > 120)
          GestureDetector(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                expanded ? 'Show less' : 'Read more',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.roseDeep,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// COMPATIBILITY SECTION
// ─────────────────────────────────────────────

class _CompatibilitySection extends StatelessWidget {
  const _CompatibilitySection({required this.candidate});
  final CandidateCard candidate;

  Color get _tierColor {
    final s = candidate.compatibilityScore;
    if (s >= 85) return AppColors.compatExceptional;
    if (s >= 72) return AppColors.compatStrong;
    if (s >= 58) return AppColors.compatGood;
    if (s >= 42) return AppColors.compatModerate;
    return AppColors.compatLow;
  }

  String get _tierLabel {
    final s = candidate.compatibilityScore;
    if (s >= 85) return 'Exceptional match';
    if (s >= 72) return 'Strong match';
    if (s >= 58) return 'Good match';
    if (s >= 42) return 'Moderate match';
    return 'Low match';
  }

  @override
  Widget build(BuildContext context) {
    if (candidate.compatibilityScore <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color:        _tierColor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: _tierColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.favorite_rounded, color: _tierColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_tierLabel — ${candidate.compatibilityScore.round()}% compatibility',
                  style: AppTypography.labelSmall.copyWith(
                    color:      _tierColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (candidate.hasAiScore)
                  Text(
                    'AI values analysis included',
                    style: AppTypography.labelSmall.copyWith(
                      color: _tierColor.withOpacity(0.7),
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${candidate.compatibilityScore.round()}%',
            style: AppTypography.titleMedium.copyWith(
              color:      _tierColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ACTION ROW
// ─────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.onInterest,
    required this.onDismiss,
    required this.onExpand,
  });
  final VoidCallback onInterest;
  final VoidCallback onDismiss;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Dismiss
        _CircleAction(
          icon:    Icons.close_rounded,
          color:   AppColors.neutral300,
          onTap:   onDismiss,
          tooltip: 'Not now',
        ),
        const SizedBox(width: 12),

        // View full profile
        _CircleAction(
          icon:    Icons.person_outline_rounded,
          color:   AppColors.neutral300,
          onTap:   onExpand,
          tooltip: 'Full profile',
        ),

        const Spacer(),

        // Express interest — primary CTA
        Expanded(
          flex: 3,
          child: MiskButton(
            label:    'Express Interest',
            onPressed: onInterest,
            icon:     Icons.favorite_rounded,
          ),
        ),
      ],
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });
  final IconData icon;
  final Color    color;
  final VoidCallback onTap;
  final String   tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap:        onTap,
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color:  color.withOpacity(0.15),
            shape:  BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }
}
