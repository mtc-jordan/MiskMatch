import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/profile_provider.dart';
import '../data/profile_models.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/shared/widgets/common_widgets.dart';

/// 5-step profile creation / edit wizard.
/// Steps: Basic → Islamic → Life Goals → Career → Bio & Media

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
  String?   _country;
  Madhab?   _madhab;
  PrayerFrequency? _prayer;
  HijabStance?     _hijab;
  String?   _quranLevel;
  bool      _isRevert     = false;
  bool?     _wantsChildren;
  String?   _childrenCount;
  String?   _hajjTimeline;
  bool      _wantsHijra   = false;
  String?   _financeStance;
  String?   _wifeWorking;
  String?   _educationLevel;
  String?   _occupation;
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
    // Pre-fill from existing profile
    final profile = ref.read(myProfileProvider);
    if (profile != null) {
      _firstNameCtrl.text = profile.firstName;
      _lastNameCtrl.text  = profile.lastName;
      _cityCtrl.text      = profile.city ?? '';
      _bioCtrl.text       = profile.bio ?? '';
      _country            = profile.country;
      _madhab             = profile.madhab;
      _prayer             = profile.prayerFrequency;
      _hijab              = profile.hijabStance;
      _quranLevel         = profile.quranLevel;
      _isRevert           = profile.isRevert;
      _wantsChildren      = profile.wantsChildren;
      _childrenCount      = profile.numChildrenDesired;
      _hajjTimeline       = profile.hajjTimeline;
      _wantsHijra         = profile.wantsHijra;
      _financeStance      = profile.islamicFinanceStance;
      _wifeWorking        = profile.wifeWorkingStance;
      _educationLevel     = profile.educationLevel;
      _occupation         = profile.occupation;
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _cityCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_step < _stepTitles.length - 1) {
      setState(() => _step++);
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic);
    } else {
      _save();
    }
  }

  void _prevStep() {
    if (_step > 0) {
      setState(() => _step--);
      _pageCtrl.previousPage(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic);
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
      city:          _cityCtrl.text.trim(),
      country:       _country,
      bio:           _bioCtrl.text.trim(),
      madhab:        _madhab,
      prayerFrequency: _prayer,
      hijabStance:   _hijab,
      quranLevel:    _quranLevel,
      isRevert:      _isRevert,
      wantsChildren: _wantsChildren,
      numChildrenDesired: _childrenCount,
      hajjTimeline:  _hajjTimeline,
      wantsHijra:    _wantsHijra,
      islamicFinanceStance: _financeStance,
      wifeWorkingStance:    _wifeWorking,
      educationLevel:_educationLevel,
      occupation:    _occupation,
    );

    final success = existing == null
        ? await ref.read(profileProvider.notifier).createProfile(profile)
        : await ref.read(profileProvider.notifier).updateProfile(profile);

    setState(() => _isSaving = false);

    if (mounted) {
      if (success) {
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _prevStep,
        ),
        title: Text(_stepTitles[_step],
            style: AppTypography.titleMedium),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Step ${_step + 1} of ${_stepTitles.length}',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.neutral500),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Progress bar ──────────────────────────────────────────
          LinearProgressIndicator(
            value:            (_step + 1) / _stepTitles.length,
            backgroundColor:  AppColors.roseLight.withOpacity(0.3),
            valueColor: const AlwaysStoppedAnimation(AppColors.roseDeep),
            minHeight: 3,
          ),

          // ── Step pages ────────────────────────────────────────────
          Expanded(
            child: PageView(
              controller:  _pageCtrl,
              physics:     const NeverScrollableScrollPhysics(),
              children: [
                _StepBasic(
                  firstNameCtrl: _firstNameCtrl,
                  lastNameCtrl:  _lastNameCtrl,
                  cityCtrl:      _cityCtrl,
                  country:       _country,
                  onCountry:     (v) => setState(() => _country = v),
                ),
                _StepIslamic(
                  madhab:     _madhab,
                  prayer:     _prayer,
                  hijab:      _hijab,
                  quranLevel: _quranLevel,
                  isRevert:   _isRevert,
                  onMadhab:   (v) => setState(() => _madhab = v),
                  onPrayer:   (v) => setState(() => _prayer = v),
                  onHijab:    (v) => setState(() => _hijab = v),
                  onQuran:    (v) => setState(() => _quranLevel = v),
                  onRevert:   (v) => setState(() => _isRevert = v),
                ),
                _StepLifeGoals(
                  wantsChildren: _wantsChildren,
                  childrenCount: _childrenCount,
                  hajjTimeline:  _hajjTimeline,
                  wantsHijra:    _wantsHijra,
                  financeStance: _financeStance,
                  wifeWorking:   _wifeWorking,
                  onWantsChildren: (v) => setState(() => _wantsChildren = v),
                  onChildrenCount: (v) => setState(() => _childrenCount = v),
                  onHajj:          (v) => setState(() => _hajjTimeline = v),
                  onHijra:         (v) => setState(() => _wantsHijra = v),
                  onFinance:       (v) => setState(() => _financeStance = v),
                  onWifeWorking:   (v) => setState(() => _wifeWorking = v),
                ),
                _StepCareer(
                  educationLevel: _educationLevel,
                  occupation:     _occupation,
                  onEducation:    (v) => setState(() => _educationLevel = v),
                  onOccupation:   (v) => setState(() => _occupation = v),
                ),
                _StepBio(bioCtrl: _bioCtrl),
              ],
            ),
          ),

          // ── Bottom action ─────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: MiskButton(
                label:     _step < _stepTitles.length - 1
                    ? 'Continue'
                    : 'Save profile',
                onPressed: _nextStep,
                loading:   _isSaving,
                icon:      _step < _stepTitles.length - 1
                    ? Icons.arrow_forward_rounded
                    : Icons.check_circle_outline_rounded,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// STEP WIDGETS
// ─────────────────────────────────────────────

class _StepBasic extends StatelessWidget {
  const _StepBasic({
    required this.firstNameCtrl, required this.lastNameCtrl,
    required this.cityCtrl, required this.country, required this.onCountry,
  });
  final TextEditingController firstNameCtrl, lastNameCtrl, cityCtrl;
  final String?               country;
  final void Function(String) onCountry;

  @override
  Widget build(BuildContext context) {
    return _StepScroll(children: [
      const _StepHeader(
        emoji: '👤', title: 'Tell us about yourself',
        subtitle: 'This is how others will see you on MiskMatch.',
      ),
      MiskTextField(label: 'First name',  controller: firstNameCtrl,
          textInputAction: TextInputAction.next),
      const SizedBox(height: 14),
      MiskTextField(label: 'Last name',   controller: lastNameCtrl,
          textInputAction: TextInputAction.next),
      const SizedBox(height: 14),
      MiskTextField(label: 'City',        controller: cityCtrl,
          prefixIcon: const Icon(Icons.location_city_outlined),
          textInputAction: TextInputAction.next),
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

class _StepIslamic extends StatelessWidget {
  const _StepIslamic({
    required this.madhab, required this.prayer, required this.hijab,
    required this.quranLevel, required this.isRevert,
    required this.onMadhab, required this.onPrayer, required this.onHijab,
    required this.onQuran, required this.onRevert,
  });
  final Madhab?          madhab;
  final PrayerFrequency? prayer;
  final HijabStance?     hijab;
  final String?          quranLevel;
  final bool             isRevert;
  final void Function(Madhab)          onMadhab;
  final void Function(PrayerFrequency) onPrayer;
  final void Function(HijabStance)     onHijab;
  final void Function(String)          onQuran;
  final void Function(bool)            onRevert;

  @override
  Widget build(BuildContext context) {
    return _StepScroll(children: [
      const _StepHeader(
        emoji: '🕌', title: 'Islamic identity',
        subtitle: 'Share your Islamic practice — the foundation of compatibility.',
      ),
      _ChoiceGroup<PrayerFrequency>(
        label:    'Prayer frequency',
        options:  PrayerFrequency.values,
        selected: prayer,
        label_of: (v) => '${v.emoji} ${v.label}',
        onSelect: onPrayer,
      ),
      const SizedBox(height: 16),
      _ChoiceGroup<Madhab>(
        label:    'Madhab',
        options:  Madhab.values,
        selected: madhab,
        label_of: (v) => v.label,
        onSelect: onMadhab,
      ),
      const SizedBox(height: 16),
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
      const SizedBox(height: 16),
      _ChoiceGroup<HijabStance>(
        label:    'Hijab',
        options:  HijabStance.values.where((v) => v != HijabStance.na).toList(),
        selected: hijab,
        label_of: (v) => v.label,
        onSelect: onHijab,
      ),
      const SizedBox(height: 16),
      SwitchListTile(
        value:          isRevert,
        onChanged:      onRevert,
        title:          Text('I am a Muslim revert', style: AppTypography.bodyMedium),
        activeColor:    AppColors.roseDeep,
        contentPadding: EdgeInsets.zero,
      ),
    ]);
  }
}

class _StepLifeGoals extends StatelessWidget {
  const _StepLifeGoals({
    required this.wantsChildren, required this.childrenCount,
    required this.hajjTimeline, required this.wantsHijra,
    required this.financeStance, required this.wifeWorking,
    required this.onWantsChildren, required this.onChildrenCount,
    required this.onHajj, required this.onHijra,
    required this.onFinance, required this.onWifeWorking,
  });
  final bool?     wantsChildren;
  final String?   childrenCount, hajjTimeline, financeStance, wifeWorking;
  final bool      wantsHijra;
  final void Function(bool?)   onWantsChildren;
  final void Function(String)  onChildrenCount;
  final void Function(String)  onHajj;
  final void Function(bool)    onHijra;
  final void Function(String)  onFinance;
  final void Function(String)  onWifeWorking;

  @override
  Widget build(BuildContext context) {
    return _StepScroll(children: [
      const _StepHeader(
        emoji: '🌙', title: 'Life goals',
        subtitle: 'Shared life goals are a strong compatibility signal.',
      ),
      Text('Children', style: AppTypography.titleSmall),
      const SizedBox(height: 10),
      Row(children: [
        _ToggleChip(label: 'Yes', selected: wantsChildren == true,
            onTap: () => onWantsChildren(true)),
        const SizedBox(width: 10),
        _ToggleChip(label: 'No', selected: wantsChildren == false,
            onTap: () => onWantsChildren(false)),
        const SizedBox(width: 10),
        _ToggleChip(label: 'Open', selected: wantsChildren == null,
            onTap: () => onWantsChildren(null)),
      ]),
      const SizedBox(height: 16),
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
      const SizedBox(height: 16),
      SwitchListTile(
        value:     wantsHijra,
        onChanged: onHijra,
        title:     Text('I want to make hijra', style: AppTypography.bodyMedium),
        activeColor: AppColors.roseDeep,
        contentPadding: EdgeInsets.zero,
      ),
    ]);
  }
}

class _StepCareer extends StatelessWidget {
  const _StepCareer({
    required this.educationLevel, required this.occupation,
    required this.onEducation, required this.onOccupation,
  });
  final String?              educationLevel, occupation;
  final void Function(String) onEducation, onOccupation;

  @override
  Widget build(BuildContext context) {
    final occCtrl = TextEditingController(text: occupation ?? '');
    return _StepScroll(children: [
      const _StepHeader(
        emoji: '🎓', title: 'Education & Career',
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
        onChanged:  onOccupation,
      ),
    ]);
  }
}

class _StepBio extends StatelessWidget {
  const _StepBio({required this.bioCtrl});
  final TextEditingController bioCtrl;

  @override
  Widget build(BuildContext context) {
    return _StepScroll(children: [
      const _StepHeader(
        emoji: '✍️', title: 'About you',
        subtitle: 'This is the richest signal for AI compatibility matching. '
            'Write naturally — what you value, your relationship with Islam, '
            'what you are looking for.',
      ),
      MiskTextField(
        label:      'Bio',
        hint:       'A practicing Muslim from Amman. I value family deeply and '
            'strive to make Islam central to every day...',
        controller: bioCtrl,
        maxLines:   8,
        maxLength:  500,
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.goldPrimary.withOpacity(0.07),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(children: [
          const Text('🤍', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Our AI reads your bio to find deeper value alignment '
              'beyond what the individual fields can capture.',
              style: AppTypography.bodySmall.copyWith(
                color:  AppColors.goldDark, height: 1.5),
            ),
          ),
        ]),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────
// SHARED STEP COMPONENTS
// ─────────────────────────────────────────────

class _StepScroll extends StatelessWidget {
  const _StepScroll({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding, 20, AppSpacing.screenPadding, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.emoji, required this.title, required this.subtitle,
  });
  final String emoji, title, subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 36)),
        const SizedBox(height: 12),
        Text(title, style: AppTypography.headlineSmall),
        const SizedBox(height: 6),
        Text(subtitle,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.neutral500, height: 1.5)),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _ChoiceGroup<T> extends StatelessWidget {
  const _ChoiceGroup({
    required this.label, required this.options, required this.selected,
    required this.label_of, required this.onSelect,
  });
  final String         label;
  final List<T>        options;
  final T?             selected;
  final String Function(T) label_of;
  final void Function(T)   onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              onTap: () => onSelect(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
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
                child: Text(label_of(opt),
                    style: AppTypography.labelMedium.copyWith(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : AppColors.neutral700,
                    )),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label, required this.value,
    required this.items, required this.onChanged,
  });
  final String                     label;
  final String?                    value;
  final Map<String, String>        items;
  final void Function(String?)     onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value:       items.containsKey(value) ? value : null,
      decoration:  InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary, width: 2)),
      ),
      items: items.entries.map((e) => DropdownMenuItem(
        value: e.key,
        child: Text(e.value, style: AppTypography.bodyMedium),
      )).toList(),
      onChanged: onChanged,
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label, required this.selected, required this.onTap,
  });
  final String       label;
  final bool         selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color:        selected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surface,
          borderRadius: AppRadius.chipRadius,
          border: Border.all(
            color:  selected ? theme.colorScheme.primary : theme.colorScheme.outline,
            width:  selected ? 2 : 1,
          ),
        ),
        child: Text(label,
            style: AppTypography.labelMedium.copyWith(
              color: selected ? theme.colorScheme.primary : AppColors.neutral700)),
      ),
    );
  }
}
