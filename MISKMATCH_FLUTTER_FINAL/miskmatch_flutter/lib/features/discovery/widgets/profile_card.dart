import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:miskmatch/features/profile/data/profile_models.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/shared/widgets/common_widgets.dart';
import 'voice_player.dart';
import 'package:miskmatch/l10n/generated/app_localizations.dart';

/// Trendy Hinge-style discovery card.
/// Full-bleed hero photo, frosted-glass name overlay,
/// rich Islamic practice section, animated actions.

class ProfileCard extends StatefulWidget {
  const ProfileCard({
    super.key,
    required this.candidate,
    required this.onInterest,
    required this.onDismiss,
    required this.onExpand,
    this.index = 0,
  });

  final CandidateCard  candidate;
  final VoidCallback   onInterest;
  final VoidCallback   onDismiss;
  final VoidCallback   onExpand;
  final int            index;

  @override
  State<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard> {
  bool _bioExpanded = false;

  UserProfile get profile => widget.candidate.profile;
  double      get score   => widget.candidate.compatibilityScore;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color:        context.cardSurface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color:      AppColors.roseDeep.withOpacity(0.08),
            blurRadius: 24,
            offset:     const Offset(0, 8),
          ),
          ...context.cardShadow,
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Hero photo with glass overlay ─────────────
            _HeroSection(
              profile: profile,
              score:   score,
              hasAi:   widget.candidate.hasAiScore,
              onTap:   widget.onExpand,
            ),

            // ── 2. Content body ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Voice intro
                  if (profile.hasVoiceIntro) ...[
                    VoicePlayerWidget(
                      audioUrl: profile.voiceIntroUrl!,
                      label: 'Hear ${profile.displayFirstName}\'s intro',
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Islamic practice grid
                  _IslamicPracticeGrid(profile: profile),

                  const SizedBox(height: 14),

                  // Life goals
                  _LifeGoalsPills(profile: profile),

                  // Bio
                  if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _BioSection(
                      bio:      profile.bio!,
                      expanded: _bioExpanded,
                      onToggle: () =>
                          setState(() => _bioExpanded = !_bioExpanded),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Compatibility bar
                  _CompatibilityBar(candidate: widget.candidate),

                  const SizedBox(height: 18),

                  // Actions
                  _ActionRow(
                    onInterest: widget.onInterest,
                    onDismiss:  widget.onDismiss,
                    onExpand:   widget.onExpand,
                    firstName:  profile.displayFirstName,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: widget.index * 80))
        .fadeIn(duration: 450.ms)
        .slideY(begin: 0.06, end: 0, duration: 450.ms,
                curve: Curves.easeOutCubic);
  }
}

// ─────────────────────────────────────────────
// HERO SECTION — full-bleed photo, frosted glass name
// ─────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.profile,
    required this.score,
    required this.hasAi,
    required this.onTap,
  });
  final UserProfile  profile;
  final double       score;
  final bool         hasAi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'View full profile for ${profile.displayFirstName}',
      child: GestureDetector(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: Stack(
            fit: StackFit.expand,
            children: [
            // Photo or placeholder
            profile.hasPhoto && profile.photoUrl != null
                ? CachedNetworkImage(
                    imageUrl:    profile.photoUrl!,
                    fit:         BoxFit.cover,
                    placeholder: (_, __) => _PhotoPlaceholder(profile: profile),
                    errorWidget: (_, __, ___) =>
                        _PhotoPlaceholder(profile: profile),
                  )
                : _PhotoPlaceholder(profile: profile),

            // Bottom gradient fade for text readability
            Positioned(
              left: 0, right: 0, bottom: 0,
              height: 200,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end:   Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.65),
                    ],
                  ),
                ),
              ),
            ),

            // Frosted glass name card — bottom left
            Positioned(
              left: 16, right: 16, bottom: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Name + age
                              Row(
                                children: [
                                  Text(
                                    profile.displayFirstName,
                                    style: const TextStyle(
                                      fontFamily:  'Georgia',
                                      fontSize:    24,
                                      fontWeight:  FontWeight.w700,
                                      color:       Colors.white,
                                    ),
                                  ),
                                  if (profile.age != null)
                                    Text(
                                      ', ${profile.age}',
                                      style: TextStyle(
                                        fontFamily: 'Georgia',
                                        fontSize:   24,
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // Location + occupation
                              Row(
                                children: [
                                  if (profile.locationText.isNotEmpty) ...[
                                    const Text('📍',
                                      style: TextStyle(fontSize: 11)),
                                    const SizedBox(width: 3),
                                    Text(
                                      profile.locationText,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white.withOpacity(0.8),
                                      ),
                                    ),
                                  ],
                                  if (profile.occupation != null &&
                                      profile.locationText.isNotEmpty) ...[
                                    Text('  •  ',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.4),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                  if (profile.occupation != null)
                                    Flexible(
                                      child: Text(
                                        profile.occupation!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white.withOpacity(0.7),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                              // Trust badges
                              const SizedBox(height: 8),
                              _TrustBadgesRow(profile: profile),
                            ],
                          ),
                        ),
                        // Compatibility score ring
                        if (score > 0)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(start: 10),
                            child: CompatibilityRing(score: score, size: 52),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TRUST BADGES ROW — glass pills on photo
// ─────────────────────────────────────────────

class _TrustBadgesRow extends StatelessWidget {
  const _TrustBadgesRow({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final badges = <(String, String)>[];
    if (profile.mosqueVerified)  badges.add(('🕌', 'Mosque'));
    if (profile.scholarEndorsed) badges.add(('📜', 'Scholar'));
    if (profile.idVerified)      badges.add(('✓', 'Verified'));

    if (badges.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      children: badges.map((b) {
        final (icon, label) = b;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: Colors.white.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 10)),
              const SizedBox(width: 3),
              Text(label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────
// PHOTO PLACEHOLDER — gradient + initial
// ─────────────────────────────────────────────

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
          colors: [AppColors.roseDeep, AppColors.midnightDeep],
          stops:  [0.0, 0.85],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Subtle geometric pattern
          Positioned(
            top: -40, right: -40,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.05), width: 1),
              ),
            ),
          ),
          Positioned(
            bottom: 60, left: -30,
            child: Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.04), width: 1),
              ),
            ),
          ),
          // Avatar + text
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88, height: 88,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.25), width: 2.5),
                ),
                child: Center(
                  child: Text(
                    profile.firstName.isNotEmpty
                        ? profile.firstName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize:   40,
                      color:      Colors.white,
                      fontWeight: FontWeight.w300,
                      fontFamily: 'Georgia',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('📷',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Photo reveals after mutual interest',
                      style: TextStyle(
                        color:     Colors.white.withOpacity(0.6),
                        fontSize:  12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ISLAMIC PRACTICE GRID — 2×2 with icons
// ─────────────────────────────────────────────

class _IslamicPracticeGrid extends StatelessWidget {
  const _IslamicPracticeGrid({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final items = <(String, String, String)>[]; // emoji, label, value

    final l = S.of(context)!;
    if (profile.prayerFrequency != null) {
      items.add((
        profile.prayerFrequency!.emoji,
        l.prayer,
        profile.prayerFrequency!.localizedLabel(l),
      ));
    }
    if (profile.madhab != null) {
      items.add(('📚', l.madhab, profile.madhab!.localizedLabel(l)));
    }
    if (profile.quranLevel != null && profile.quranLevel!.isNotEmpty) {
      items.add(('📖', l.quran,
          localizedQuranLevel(l, profile.quranLevel!)));
    }
    if (profile.isRevert) {
      items.add(('🌙', l.journey, profile.revertYear != null
          ? l.revertYear('${profile.revertYear}')
          : l.revertLabel));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.roseDeep.withOpacity(0.04),
            AppColors.goldPrimary.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.roseDeep.withOpacity(0.10)),
      ),
      child: Row(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final (emoji, label, value) = entry.value;
          return Expanded(
            child: Row(
              children: [
                if (i > 0)
                  Container(
                    width: 1,
                    height: 28,
                    margin: const EdgeInsetsDirectional.only(end: 10),
                    color: AppColors.roseDeep.withOpacity(0.08),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(emoji,
                            style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 4),
                          Text(label,
                            style: AppTypography.labelSmall.copyWith(
                              color:    context.mutedText,
                              fontSize: 9,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(value,
                        style: AppTypography.bodySmall.copyWith(
                          color:      context.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize:   11,
                        ),
                        maxLines: 1,
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
// LIFE GOALS PILLS — horizontal gradient pills
// ─────────────────────────────────────────────

class _LifeGoalsPills extends StatelessWidget {
  const _LifeGoalsPills({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final chips = <String>[];

    if (profile.wantsChildren == true) {
      chips.add(profile.numChildrenDesired != null
          ? l.wantsChildrenCount(profile.numChildrenDesired.toString())
          : l.wantsChildren);
    }

    if (profile.hajjTimeline != null) {
      final labels = {
        'within_1_year':  '🕋 Hajj this year',
        'within_3_years': '🕋 Hajj < 3y',
        'within_5_years': '🕋 Hajj < 5y',
        'someday':        '🕋 Hajj someday',
        'done':           '🕋 Hajj ✓',
      };
      final label = labels[profile.hajjTimeline];
      if (label != null) chips.add(label);
    }

    if (profile.islamicFinanceStance == 'strict') {
      chips.add('💚 Islamic finance');
    }
    if (profile.wantsHijra) {
      chips.add('✈️ Hijra${profile.hijraCountry != null
          ? ' → ${profile.hijraCountry}' : ''}');
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips.map((chip) {
          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.roseDeep.withOpacity(0.08),
                    AppColors.roseDeep.withOpacity(0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: AppColors.roseDeep.withOpacity(0.12)),
              ),
              child: Text(chip,
                style: AppTypography.labelSmall.copyWith(
                  color:    AppColors.roseDeep,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// BIO SECTION — expandable
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        context.subtleBg.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('💭',
                style: TextStyle(fontSize: 13,
                  color: context.mutedText)),
              const SizedBox(width: 6),
              Text(S.of(context)!.about,
                style: AppTypography.labelSmall.copyWith(
                  color:         context.mutedText,
                  fontSize:      10,
                  letterSpacing: 0.5,
                  fontWeight:    FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            bio,
            maxLines:  expanded ? null : 3,
            overflow:  expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: AppTypography.bodyMedium.copyWith(
              color:    context.subtleText,
              fontSize: 13,
              height:   1.6,
            ),
          ),
          if (bio.length > 100)
            Semantics(
              button: true,
              label: expanded ? 'Collapse bio' : 'Expand bio',
              child: GestureDetector(
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    expanded ? 'Show less' : 'Read more',
                    style: AppTypography.labelSmall.copyWith(
                      color:      AppColors.roseDeep,
                      fontSize:   11,
                      fontWeight: FontWeight.w600,
                    ),
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
// COMPATIBILITY BAR — gradient fill
// ─────────────────────────────────────────────

class _CompatibilityBar extends StatelessWidget {
  const _CompatibilityBar({required this.candidate});
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _tierColor.withOpacity(0.08),
            _tierColor.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _tierColor.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          // Animated progress arc
          SizedBox(
            width: 44, height: 44,
            child: TweenAnimationBuilder<double>(
              tween:    Tween(begin: 0, end: candidate.compatibilityScore / 100),
              duration: 800.ms,
              curve:    Curves.easeOutCubic,
              builder: (_, value, __) => Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value:           value,
                    strokeWidth:     4,
                    backgroundColor: _tierColor.withOpacity(0.12),
                    valueColor:      AlwaysStoppedAnimation(_tierColor),
                  ),
                  Text(
                    '${candidate.compatibilityScore.round()}',
                    style: TextStyle(
                      fontFamily:  'Georgia',
                      fontSize:    14,
                      fontWeight:  FontWeight.w700,
                      color:       _tierColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tierLabel,
                  style: AppTypography.titleSmall.copyWith(
                    color:      _tierColor,
                    fontWeight: FontWeight.w700,
                    fontSize:   13,
                  ),
                ),
                if (candidate.hasAiScore)
                  Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded,
                        size: 11, color: _tierColor.withOpacity(0.6)),
                      const SizedBox(width: 3),
                      Text(
                        'AI values analysis',
                        style: AppTypography.caption.copyWith(
                          color:    _tierColor.withOpacity(0.6),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Text(
            '${candidate.compatibilityScore.round()}%',
            style: TextStyle(
              fontFamily:  'Georgia',
              fontSize:    22,
              fontWeight:  FontWeight.w700,
              color:       _tierColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ACTION ROW — dismiss, profile, express interest
// ─────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.onInterest,
    required this.onDismiss,
    required this.onExpand,
    required this.firstName,
  });
  final VoidCallback onInterest;
  final VoidCallback onDismiss;
  final VoidCallback onExpand;
  final String       firstName;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Dismiss
        Semantics(
          button: true,
          label: 'Dismiss profile',
          child: _ActionCircle(
            icon:    Icons.close_rounded,
            bgColor: context.subtleBg,
            fgColor: context.mutedText,
            onTap:   onDismiss,
            size:    50,
          ),
        ),
        const SizedBox(width: 10),

        // Profile
        Semantics(
          button: true,
          label: 'View full profile',
          child: _ActionCircle(
            icon:    Icons.person_outline_rounded,
            bgColor: context.subtleBg,
            fgColor: context.mutedText,
            onTap:   onExpand,
            size:    50,
          ),
        ),

        const SizedBox(width: 12),

        // Express Interest
        Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              onInterest();
            },
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                gradient:     AppColors.roseGradient,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color:      AppColors.roseDeep.withOpacity(0.3),
                    blurRadius: 12,
                    offset:     const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.favorite_rounded,
                    color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Express Interest',
                    style: AppTypography.labelMedium.copyWith(
                      color:      Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionCircle extends StatelessWidget {
  const _ActionCircle({
    required this.icon,
    required this.bgColor,
    required this.fgColor,
    required this.onTap,
    this.size = 48,
  });
  final IconData     icon;
  final Color        bgColor;
  final Color        fgColor;
  final VoidCallback onTap;
  final double       size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color:  bgColor,
          shape:  BoxShape.circle,
          border: Border.all(
            color: fgColor.withOpacity(0.15)),
        ),
        child: Icon(icon, color: fgColor, size: 22),
      ),
    );
  }
}
