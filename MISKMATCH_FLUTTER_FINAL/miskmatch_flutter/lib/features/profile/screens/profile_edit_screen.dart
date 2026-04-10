import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/profile_provider.dart';
import '../data/profile_models.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/shared/widgets/common_widgets.dart';
import 'package:miskmatch/features/auth/providers/auth_provider.dart';

/// 5-step profile creation / edit wizard.
/// Steps: Basic → Islamic → Life Goals → Career → Bio & Voice

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _pageCtrl = PageController();
  int   _step     = 0;

  // Form data (accumulated across steps)
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  final _cityCtrl      = TextEditingController();
  final _bioCtrl       = TextEditingController();
  final _occCtrl       = TextEditingController();
  DateTime? _dateOfBirth;
  String?   _country;
  Madhab?   _madhab;
  PrayerFrequency? _prayer;
  HijabStance?     _hijab;
  String?   _quranLevel;
  bool      _isRevert     = false;
  int?      _revertYear;
  bool?     _wantsChildren;
  String?   _childrenCount;
  String?   _hajjTimeline;
  bool      _wantsHijra   = false;
  String?   _hijraCountry;
  String?   _financeStance;
  String?   _wifeWorking;
  String?   _educationLevel;
  bool      _isSaving = false;

  static const _stepTitles = [
    'Basic Info',
    'Islamic Identity',
    'Life Goals',
    'Education & Career',
    'About You',
  ];

  @override
  void initState() {
    super.initState();
    final profile = ref.read(myProfileProvider);
    if (profile != null) {
      _firstNameCtrl.text = profile.firstName;
      _lastNameCtrl.text  = profile.lastName;
      _cityCtrl.text      = profile.city ?? '';
      _bioCtrl.text       = profile.bio ?? '';
      _occCtrl.text       = profile.occupation ?? '';
      _dateOfBirth        = profile.dateOfBirth;
      _country            = profile.country;
      _madhab             = profile.madhab;
      _prayer             = profile.prayerFrequency;
      _hijab              = profile.hijabStance;
      _quranLevel         = profile.quranLevel;
      _isRevert           = profile.isRevert;
      _revertYear         = profile.revertYear;
      _wantsChildren      = profile.wantsChildren;
      _childrenCount      = profile.numChildrenDesired;
      _hajjTimeline       = profile.hajjTimeline;
      _wantsHijra         = profile.wantsHijra;
      _hijraCountry       = profile.hijraCountry;
      _financeStance      = profile.islamicFinanceStance;
      _wifeWorking        = profile.wifeWorkingStance;
      _educationLevel     = profile.educationLevel;
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _cityCtrl.dispose();
    _bioCtrl.dispose();
    _occCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_step < _stepTitles.length - 1) {
      setState(() => _step++);
      _pageCtrl.nextPage(
          duration: 350.ms, curve: Curves.easeOutCubic);
    } else {
      _save();
    }
  }

  void _prevStep() {
    if (_step > 0) {
      setState(() => _step--);
      _pageCtrl.previousPage(
          duration: 350.ms, curve: Curves.easeOutCubic);
    } else {
      context.pop();
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final existing = ref.read(myProfileProvider);
    final profile  = UserProfile(
      userId:        existing?.userId ?? '',
      firstName:     _firstNameCtrl.text.trim(),
      lastName:      _lastNameCtrl.text.trim(),
      dateOfBirth:   _dateOfBirth,
      city:          _cityCtrl.text.trim(),
      country:       _country,
      bio:           _bioCtrl.text.trim(),
      madhab:        _madhab,
      prayerFrequency: _prayer,
      hijabStance:   _hijab,
      quranLevel:    _quranLevel,
      isRevert:      _isRevert,
      revertYear:    _revertYear,
      wantsChildren: _wantsChildren,
      numChildrenDesired: _childrenCount,
      hajjTimeline:  _hajjTimeline,
      wantsHijra:    _wantsHijra,
      hijraCountry:  _hijraCountry,
      islamicFinanceStance: _financeStance,
      wifeWorkingStance:    _wifeWorking,
      educationLevel: _educationLevel,
      occupation:    _occCtrl.text.trim(),
    );

    final success = existing == null
        ? await ref.read(profileProvider.notifier).createProfile(profile)
        : await ref.read(profileProvider.notifier).updateProfile(profile);

    setState(() => _isSaving = false);

    if (mounted) {
      if (success) {
        HapticFeedback.mediumImpact();
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved. JazakAllah Khair 🌙'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save profile. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surfaceColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _prevStep,
        ),
        title: Text(_stepTitles[_step],
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: context.surfaceColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Step ${_step + 1}/5',
                style: AppTypography.bodySmall.copyWith(
                  color: context.mutedText),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Progress bar — 3px, roseDeep fill ────────────────────
          AnimatedContainer(
            duration: 350.ms,
            child: LinearProgressIndicator(
              value:           (_step + 1) / _stepTitles.length,
              backgroundColor: AppColors.roseLight.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation(AppColors.roseDeep),
              minHeight: 3,
            ),
          ),

          // ── Step pages ──────────────────────────────────────────
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics:    const NeverScrollableScrollPhysics(),
              children: [
                _StepBasic(
                  firstNameCtrl: _firstNameCtrl,
                  lastNameCtrl:  _lastNameCtrl,
                  cityCtrl:      _cityCtrl,
                  country:       _country,
                  dateOfBirth:   _dateOfBirth,
                  onCountry:     (v) => setState(() => _country = v),
                  onDateOfBirth: (v) => setState(() => _dateOfBirth = v),
                ),
                _StepIslamic(
                  madhab:     _madhab,
                  prayer:     _prayer,
                  hijab:      _hijab,
                  quranLevel: _quranLevel,
                  isRevert:   _isRevert,
                  revertYear: _revertYear,
                  isFemale:   ref.watch(currentUserGenderProvider) == 'female',
                  onMadhab:   (v) => setState(() => _madhab = v),
                  onPrayer:   (v) => setState(() => _prayer = v),
                  onHijab:    (v) => setState(() => _hijab = v),
                  onQuran:    (v) => setState(() => _quranLevel = v),
                  onRevert:   (v) => setState(() => _isRevert = v),
                  onRevertYear: (v) => setState(() => _revertYear = v),
                ),
                _StepLifeGoals(
                  wantsChildren: _wantsChildren,
                  childrenCount: _childrenCount,
                  hajjTimeline:  _hajjTimeline,
                  wantsHijra:    _wantsHijra,
                  hijraCountry:  _hijraCountry,
                  financeStance: _financeStance,
                  wifeWorking:   _wifeWorking,
                  onWantsChildren: (v) => setState(() => _wantsChildren = v),
                  onChildrenCount: (v) => setState(() => _childrenCount = v),
                  onHajj:          (v) => setState(() => _hajjTimeline = v),
                  onHijra:         (v) => setState(() => _wantsHijra = v),
                  onHijraCountry:  (v) => setState(() => _hijraCountry = v),
                  onFinance:       (v) => setState(() => _financeStance = v),
                  onWifeWorking:   (v) => setState(() => _wifeWorking = v),
                ),
                _StepCareer(
                  educationLevel: _educationLevel,
                  occCtrl:        _occCtrl,
                  onEducation:    (v) => setState(() => _educationLevel = v),
                ),
                _StepBio(bioCtrl: _bioCtrl),
              ],
            ),
          ),

          // ── Bottom action ───────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: _step < _stepTitles.length - 1
                  ? MiskButton(
                      label:     'Continue',
                      onPressed: _nextStep,
                      icon:      Icons.arrow_forward_rounded,
                    )
                      .animate()
                      .slideY(begin: 0.15, end: 0, duration: 300.ms,
                              curve: Curves.easeOutCubic)
                      .fadeIn(duration: 200.ms)
                  : MiskButton(
                      label:     'Save my profile — Bismillah',
                      onPressed: _save,
                      loading:   _isSaving,
                      variant:   MiskButtonVariant.gold,
                      icon:      Icons.check_circle_outline_rounded,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// STEP 1 — BASIC INFO
// ═══════════════════════════════════════════════════════════

class _StepBasic extends StatelessWidget {
  const _StepBasic({
    required this.firstNameCtrl, required this.lastNameCtrl,
    required this.cityCtrl, required this.country, required this.onCountry,
    required this.dateOfBirth, required this.onDateOfBirth,
  });
  final TextEditingController firstNameCtrl, lastNameCtrl, cityCtrl;
  final String?               country;
  final DateTime?             dateOfBirth;
  final void Function(String)   onCountry;
  final void Function(DateTime) onDateOfBirth;

  @override
  Widget build(BuildContext context) {
    return _StepScroll(children: [
      const _StepHeader(
        emoji:    '👤',
        title:    'Tell us about yourself',
        subtitle: 'This is how others will see you on MiskMatch.',
      ),

      // Fields animate in staggered 80ms
      MiskTextField(
        label: 'First name',
        controller: firstNameCtrl,
        textInputAction: TextInputAction.next,
      ),

      const SizedBox(height: 14),

      MiskTextField(
        label: 'Last name',
        controller: lastNameCtrl,
        textInputAction: TextInputAction.next,
      ),

      const SizedBox(height: 14),

      // Date of birth
      MiskTextField(
        label:    'Date of birth',
        hint:     'Tap to select',
        readOnly: true,
        controller: TextEditingController(
          text: dateOfBirth != null
              ? '${dateOfBirth!.day}/${dateOfBirth!.month}/${dateOfBirth!.year}'
              : '',
        ),
        prefixIcon: const Icon(Icons.cake_outlined),
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: dateOfBirth ?? DateTime(now.year - 25),
            firstDate:   DateTime(1940),
            lastDate:    DateTime(now.year - 18, now.month, now.day),
            helpText:    'You must be 18+',
          );
          if (picked != null) onDateOfBirth(picked);
        },
      ),

      const SizedBox(height: 14),

      MiskTextField(
        label: 'City',
        controller: cityCtrl,
        prefixIcon: const Icon(Icons.location_city_outlined),
        textInputAction: TextInputAction.next,
      ),

      const SizedBox(height: 14),

      _DropdownField(
        label:    'Country',
        value:    country,
        items:    const {
          'JO': '🇯🇴 Jordan',    'SA': '🇸🇦 Saudi Arabia',
          'AE': '🇦🇪 UAE',       'GB': '🇬🇧 United Kingdom',
          'US': '🇺🇸 United States', 'CA': '🇨🇦 Canada',
          'MY': '🇲🇾 Malaysia',  'EG': '🇪🇬 Egypt',
          'TR': '🇹🇷 Turkey',    'DE': '🇩🇪 Germany',
          'FR': '🇫🇷 France',    'AU': '🇦🇺 Australia',
          'PK': '🇵🇰 Pakistan',  'IN': '🇮🇳 India',
          'ID': '🇮🇩 Indonesia',
        },
        onChanged: (v) { if (v != null) onCountry(v); },
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════
// STEP 2 — ISLAMIC IDENTITY
// ═══════════════════════════════════════════════════════════

class _StepIslamic extends StatelessWidget {
  const _StepIslamic({
    required this.madhab, required this.prayer, required this.hijab,
    required this.quranLevel, required this.isRevert, required this.revertYear,
    required this.isFemale,
    required this.onMadhab, required this.onPrayer, required this.onHijab,
    required this.onQuran, required this.onRevert, required this.onRevertYear,
  });
  final Madhab?          madhab;
  final PrayerFrequency? prayer;
  final HijabStance?     hijab;
  final String?          quranLevel;
  final bool             isRevert;
  final int?             revertYear;
  final bool             isFemale;
  final void Function(Madhab)          onMadhab;
  final void Function(PrayerFrequency) onPrayer;
  final void Function(HijabStance)     onHijab;
  final void Function(String)          onQuran;
  final void Function(bool)            onRevert;
  final void Function(int?)            onRevertYear;

  @override
  Widget build(BuildContext context) {
    return _StepScroll(children: [
      const _StepHeader(
        emoji:    '🕌',
        title:    'Your deen, your identity',
        subtitle: 'Share your Islamic practice — the foundation of compatibility.',
      ),

      // Prayer frequency — choice chips
      _ChoiceChipGroup<PrayerFrequency>(
        label:    'Prayer frequency',
        options:  PrayerFrequency.values,
        selected: prayer,
        labelOf:  (v) => '${v.emoji} ${v.label}',
        onSelect: onPrayer,
      ),

      const SizedBox(height: 20),

      // Madhab — choice chips
      _ChoiceChipGroup<Madhab>(
        label:    'Madhab',
        options:  Madhab.values,
        selected: madhab,
        labelOf:  (v) => v.label,
        onSelect: onMadhab,
      ),

      const SizedBox(height: 20),

      // Quran level — dropdown with checkmark
      _DropdownField(
        label:    'Quran level',
        value:    quranLevel,
        items:    const {
          'hafiz':           '📖 Full Hafiz',
          'hafiz_partial':   '📖 Partial Hafiz',
          'memorising':      '📖 Currently memorising',
          'recites_tajweed': '📖 Recites with Tajweed',
          'strong':          '📖 Strong recitation',
          'learning':        '📖 Learning',
          'beginner':        '📖 Beginner',
        },
        onChanged: (v) { if (v != null) onQuran(v); },
      ),

      // Hijab — gender-appropriate
      if (isFemale) ...[
        const SizedBox(height: 20),
        _ChoiceChipGroup<HijabStance>(
          label:    'Hijab',
          options:  HijabStance.values.where((v) => v != HijabStance.na).toList(),
          selected: hijab,
          labelOf:  (v) => v.label,
          onSelect: onHijab,
        ),
      ],

      const SizedBox(height: 20),

      // Revert toggle — custom animated
      _RevertToggle(
        isRevert:   isRevert,
        revertYear: revertYear,
        onRevert:   onRevert,
        onYear:     onRevertYear,
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════
// STEP 3 — LIFE GOALS
// ═══════════════════════════════════════════════════════════

class _StepLifeGoals extends StatelessWidget {
  const _StepLifeGoals({
    required this.wantsChildren, required this.childrenCount,
    required this.hajjTimeline, required this.wantsHijra,
    required this.hijraCountry,
    required this.financeStance, required this.wifeWorking,
    required this.onWantsChildren, required this.onChildrenCount,
    required this.onHajj, required this.onHijra, required this.onHijraCountry,
    required this.onFinance, required this.onWifeWorking,
  });
  final bool?     wantsChildren;
  final String?   childrenCount, hajjTimeline, financeStance,
                  wifeWorking, hijraCountry;
  final bool      wantsHijra;
  final void Function(bool?)   onWantsChildren;
  final void Function(String)  onChildrenCount;
  final void Function(String)  onHajj;
  final void Function(bool)    onHijra;
  final void Function(String)  onHijraCountry;
  final void Function(String)  onFinance;
  final void Function(String)  onWifeWorking;

  @override
  Widget build(BuildContext context) {
    return _StepScroll(children: [
      const _StepHeader(
        emoji:    '🌙',
        title:    'Life goals',
        subtitle: 'Shared life goals are a strong compatibility signal.',
      ),

      // Children — 3 toggle buttons side by side
      Text('Children', style: AppTypography.titleSmall),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: _TripleToggle(
              label:    'Yes',
              selected: wantsChildren == true,
              onTap:    () => onWantsChildren(true),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _TripleToggle(
              label:    'Open',
              selected: wantsChildren == null,
              onTap:    () => onWantsChildren(null),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _TripleToggle(
              label:    'No',
              selected: wantsChildren == false,
              onTap:    () => onWantsChildren(false),
            ),
          ),
        ],
      ),

      const SizedBox(height: 20),

      // Hajj timeline
      _DropdownField(
        label:    'Hajj timeline',
        value:    hajjTimeline,
        items:    const {
          'within_1_year':  '🕋 This year',
          'within_3_years': '🕋 Within 3 years',
          'within_5_years': '🕋 Within 5 years',
          'someday':        '🕋 Someday',
          'done':           '🕋 Already performed',
        },
        onChanged: (v) { if (v != null) onHajj(v); },
      ),

      const SizedBox(height: 16),

      // Islamic finance
      _DropdownField(
        label:    'Islamic finance stance',
        value:    financeStance,
        items:    const {
          'strict':   '💚 Strictly Islamic finance only',
          'prefers':  '💚 Prefers Islamic finance',
          'learning': '📚 Still learning',
          'open':     '🤝 Open to conventional',
        },
        onChanged: (v) { if (v != null) onFinance(v); },
      ),

      const SizedBox(height: 20),

      // Hijra toggle row
      _HijraToggle(
        wantsHijra:   wantsHijra,
        hijraCountry: hijraCountry,
        onHijra:      onHijra,
        onCountry:    onHijraCountry,
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════
// STEP 4 — CAREER
// ═══════════════════════════════════════════════════════════

class _StepCareer extends StatelessWidget {
  const _StepCareer({
    required this.educationLevel,
    required this.occCtrl,
    required this.onEducation,
  });
  final String?              educationLevel;
  final TextEditingController occCtrl;
  final void Function(String) onEducation;

  @override
  Widget build(BuildContext context) {
    return _StepScroll(children: [
      const _StepHeader(
        emoji:    '🎓',
        title:    'Education & Career',
        subtitle: 'Optional — helps find compatible life trajectories.',
      ),

      _DropdownField(
        label:    'Education level',
        value:    educationLevel,
        items:    const {
          'high_school':  'High school',
          'bachelors':    "Bachelor's degree",
          'masters':      "Master's degree",
          'doctorate':    'Doctorate / PhD',
          'vocational':   'Vocational / Trade',
          'self_taught':  'Self-taught',
        },
        onChanged: (v) { if (v != null) onEducation(v); },
      ),

      const SizedBox(height: 16),

      MiskTextField(
        label:      'Occupation',
        hint:       'e.g. Software Engineer, Doctor, Teacher',
        controller: occCtrl,
        prefixIcon: const Icon(Icons.work_outline_rounded),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════
// STEP 5 — BIO & VOICE
// ═══════════════════════════════════════════════════════════

class _StepBio extends StatefulWidget {
  const _StepBio({required this.bioCtrl});
  final TextEditingController bioCtrl;

  @override
  State<_StepBio> createState() => _StepBioState();
}

class _StepBioState extends State<_StepBio> {
  @override
  void initState() {
    super.initState();
    widget.bioCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final charCount = widget.bioCtrl.text.length;

    return _StepScroll(children: [
      const _StepHeader(
        emoji:    '✍️',
        title:    'About you',
        subtitle: 'This is the richest signal for AI compatibility matching.',
      ),

      // ── Voice intro section ─────────────────────────────────
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.roseDeep.withOpacity(0.3),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          children: [
            const Text('🎙️', style: TextStyle(fontSize: 36)),
            const SizedBox(height: 12),
            Text('Record your voice introduction',
              textAlign: TextAlign.center,
              style: AppTypography.titleSmall.copyWith(
                color:      context.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '60 seconds maximum. Let them hear you before they see you.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color:  context.mutedText,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            // Record button — large rose circle 80px
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                gradient: AppColors.roseGradient,
                shape:    BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color:      AppColors.roseDeep.withOpacity(0.3),
                    blurRadius: 20,
                    offset:     const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.mic_rounded,
                  color: AppColors.white, size: 36),
            ),
            const SizedBox(height: 10),
            Text('Tap to record',
              style: AppTypography.bodySmall.copyWith(
                color: context.mutedText),
            ),
          ],
        ),
      )
          .animate()
          .fadeIn(duration: 400.ms)
          .slideY(begin: 0.05, end: 0, duration: 400.ms),

      const SizedBox(height: 24),

      // ── Bio textarea ────────────────────────────────────────
      Container(
        decoration: BoxDecoration(
          color:        context.subtleBg.withOpacity(0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: context.cardBorder.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            TextField(
              controller:    widget.bioCtrl,
              maxLines:      10,
              maxLength:     1000,
              textDirection: TextDirection.ltr,
              style: AppTypography.bodyMedium.copyWith(
                color:  context.onSurface,
                height: 1.6,
              ),
              decoration: InputDecoration(
                hintText: 'A practicing Muslim from Amman. I value family '
                    'deeply and strive to make Islam central to every day...',
                hintStyle: AppTypography.bodyMedium.copyWith(
                  color: context.mutedText.withOpacity(0.5)),
                hintMaxLines: 3,
                border:         InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
                counterText: '',
              ),
            ),
            // Character counter
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 16, 12),
              child: Text(
                '$charCount / 1000',
                style: AppTypography.caption.copyWith(
                  color: charCount > 900
                      ? AppColors.roseDeep
                      : context.mutedText,
                ),
              ),
            ),
          ],
        ),
      )
          .animate(delay: 100.ms)
          .fadeIn(duration: 400.ms),

      const SizedBox(height: 12),

      // ── Gold shimmer AI tip ─────────────────────────────────
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:        AppColors.goldPrimary.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          const Text('✨', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your bio is read by our AI to find deeper matches',
              style: AppTypography.bodySmall.copyWith(
                color:  AppColors.goldDark,
                height: 1.5,
              ),
            ),
          ),
        ]),
      )
          .animate(delay: 200.ms)
          .fadeIn(duration: 400.ms)
          .shimmer(duration: 2000.ms, delay: 1000.ms,
                   color: AppColors.goldLight.withOpacity(0.3)),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════
// SHARED COMPONENTS
// ═══════════════════════════════════════════════════════════

class _StepScroll extends StatelessWidget {
  const _StepScroll({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// STEP HEADER — emoji + title + subtitle
// ─────────────────────────────────────────────

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.emoji,
    required this.title,
    required this.subtitle,
  });
  final String emoji, title, subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Emoji
        Text(emoji, style: const TextStyle(fontSize: 36)),

        const SizedBox(height: 12),

        // Title — Georgia 26pt
        Text(title,
          style: TextStyle(
            fontFamily:  'Georgia',
            fontSize:    26,
            fontWeight:  FontWeight.w700,
            color:       context.onSurface,
          ),
        ),

        const SizedBox(height: 6),

        // Subtitle
        Text(subtitle,
          style: AppTypography.bodyMedium.copyWith(
            color:    context.mutedText,
            fontSize: 13,
            height:   1.5,
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// CHOICE CHIP GROUP — roseGradient on select
// ─────────────────────────────────────────────

class _ChoiceChipGroup<T> extends StatelessWidget {
  const _ChoiceChipGroup({
    required this.label,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelect,
  });
  final String              label;
  final List<T>             options;
  final T?                  selected;
  final String Function(T)  labelOf;
  final void Function(T)    onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.titleSmall),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: options.map((opt) {
            final isSelected = opt == selected;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onSelect(opt);
              },
              child: AnimatedContainer(
                duration: 180.ms,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  gradient: isSelected ? AppColors.roseGradient : null,
                  color:    isSelected ? null : context.subtleBg,
                  borderRadius: BorderRadius.circular(100),
                  border: isSelected
                      ? null
                      : Border.all(color: context.cardBorder),
                  boxShadow: isSelected
                      ? [BoxShadow(
                          color:      AppColors.roseDeep.withOpacity(0.2),
                          blurRadius: 8,
                          offset:     const Offset(0, 2),
                        )]
                      : null,
                ),
                child: Text(labelOf(opt),
                  style: AppTypography.labelMedium.copyWith(
                    color: isSelected
                        ? AppColors.white
                        : context.subtleText,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// REVERT TOGGLE — custom animated switch
// ─────────────────────────────────────────────

class _RevertToggle extends StatelessWidget {
  const _RevertToggle({
    required this.isRevert,
    required this.revertYear,
    required this.onRevert,
    required this.onYear,
  });
  final bool               isRevert;
  final int?               revertYear;
  final void Function(bool) onRevert;
  final void Function(int?) onYear;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Full-width toggle row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color:        isRevert
                ? AppColors.roseDeep.withOpacity(0.06)
                : context.subtleBg.withOpacity(0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isRevert
                  ? AppColors.roseDeep.withOpacity(0.2)
                  : context.cardBorder.withOpacity(0.5),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.nightlight_round,
                  color: isRevert
                      ? AppColors.roseDeep
                      : context.mutedText,
                  size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text('I am a Muslim revert',
                  style: AppTypography.bodyMedium.copyWith(
                    color: isRevert
                        ? context.onSurface
                        : context.subtleText,
                  ),
                ),
              ),
              Switch(
                value:       isRevert,
                onChanged:   (v) {
                  HapticFeedback.selectionClick();
                  onRevert(v);
                  if (!v) onYear(null);
                },
                activeColor: AppColors.roseDeep,
              ),
            ],
          ),
        ),

        // Year field slides in
        AnimatedSize(
          duration: 300.ms,
          curve:    Curves.easeOutCubic,
          child: isRevert
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _DropdownField(
                    label: 'Year of reversion',
                    value: revertYear?.toString(),
                    items: {
                      for (int y = DateTime.now().year; y >= 1950; y--)
                        y.toString(): y.toString(),
                    },
                    onChanged: (v) {
                      if (v != null) onYear(int.tryParse(v));
                    },
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// HIJRA TOGGLE — with country reveal
// ─────────────────────────────────────────────

class _HijraToggle extends StatelessWidget {
  const _HijraToggle({
    required this.wantsHijra,
    required this.hijraCountry,
    required this.onHijra,
    required this.onCountry,
  });
  final bool                 wantsHijra;
  final String?              hijraCountry;
  final void Function(bool)   onHijra;
  final void Function(String) onCountry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: wantsHijra
                ? AppColors.roseDeep.withOpacity(0.06)
                : context.subtleBg.withOpacity(0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: wantsHijra
                  ? AppColors.roseDeep.withOpacity(0.2)
                  : context.cardBorder.withOpacity(0.5),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.flight_takeoff_rounded,
                  color: wantsHijra
                      ? AppColors.roseDeep
                      : context.mutedText,
                  size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text('I want to make hijra',
                  style: AppTypography.bodyMedium.copyWith(
                    color: wantsHijra
                        ? context.onSurface
                        : context.subtleText,
                  ),
                ),
              ),
              Switch(
                value:       wantsHijra,
                onChanged:   (v) {
                  HapticFeedback.selectionClick();
                  onHijra(v);
                },
                activeColor: AppColors.roseDeep,
              ),
            ],
          ),
        ),

        // Country field reveals
        AnimatedSize(
          duration: 300.ms,
          curve:    Curves.easeOutCubic,
          child: wantsHijra
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: MiskTextField(
                    label: 'Hijra destination country',
                    hint:  'e.g. Malaysia, Turkey, Jordan',
                    controller: TextEditingController(
                        text: hijraCountry ?? ''),
                    prefixIcon: const Icon(Icons.public_rounded),
                    onChanged: onCountry,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// TRIPLE TOGGLE — 1/3 width each
// ─────────────────────────────────────────────

class _TripleToggle extends StatelessWidget {
  const _TripleToggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String       label;
  final bool         selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: 180.ms,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient:     selected ? AppColors.roseGradient : null,
          color:        selected ? null : context.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: selected
              ? null
              : Border.all(color: context.cardBorder),
          boxShadow: selected
              ? [BoxShadow(
                  color:      AppColors.roseDeep.withOpacity(0.2),
                  blurRadius: 8,
                  offset:     const Offset(0, 2),
                )]
              : null,
        ),
        child: Center(
          child: Text(label,
            style: AppTypography.labelMedium.copyWith(
              color:      selected ? AppColors.white : context.subtleText,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// DROPDOWN FIELD — themed
// ─────────────────────────────────────────────

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String                 label;
  final String?                value;
  final Map<String, String>    items;
  final void Function(String?) onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value:      items.containsKey(value) ? value : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTypography.bodyMedium.copyWith(
          color: context.mutedText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: context.cardBorder.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.roseDeep, width: 2),
        ),
        filled: true,
        fillColor: context.subtleBg.withOpacity(0.3),
      ),
      selectedItemBuilder: (context) {
        return items.entries.map((e) {
          return Row(
            children: [
              Expanded(child: Text(e.value,
                  style: AppTypography.bodyMedium)),
              if (e.key == value)
                const Icon(Icons.check_rounded,
                    color: AppColors.success, size: 18),
            ],
          );
        }).toList();
      },
      items: items.entries.map((e) => DropdownMenuItem(
        value: e.key,
        child: Text(e.value, style: AppTypography.bodyMedium),
      )).toList(),
      onChanged: onChanged,
    );
  }
}
