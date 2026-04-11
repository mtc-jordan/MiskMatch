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
import 'package:miskmatch/features/wali/data/wali_repository.dart';
import 'package:miskmatch/features/wali/data/wali_models.dart';
import 'package:miskmatch/l10n/generated/app_localizations.dart';
import 'package:miskmatch/shared/models/api_response.dart';

/// Wali (guardian) setup — 3-step onboarding wizard.

class WaliSetupScreen extends ConsumerStatefulWidget {
  const WaliSetupScreen({super.key});

  @override
  ConsumerState<WaliSetupScreen> createState() => _WaliSetupScreenState();
}

class _WaliSetupScreenState extends ConsumerState<WaliSetupScreen> {
  final _pageCtrl  = PageController();
  int   _step      = 0;

  // Step 1 — relationship
  String? _relationship;

  // Step 2 — details
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _dialCode = '+962';
  String _flag     = '🇯🇴';

  // Step 3 — permissions
  bool _approveMatches = true;
  bool _readConvos     = false;
  bool _notifications  = true;
  bool _joinCalls      = true;

  bool _loading = false;

  List<(String, String, IconData)> _relationships(BuildContext context) {
    final l = S.of(context)!;
    return [
      ('father',      l.waliRelFather,      Icons.man_rounded),
      ('brother',     l.waliRelBrother,     Icons.person_rounded),
      ('uncle',       l.waliRelUncle,       Icons.elderly_rounded),
      ('grandfather', l.waliRelGrandfather, Icons.elderly_rounded),
      ('imam',        l.waliRelImam,        Icons.mosque_rounded),
      ('other',       l.waliRelOther,       Icons.group_rounded),
    ];
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_step < 2) {
      setState(() => _step++);
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic);
    } else {
      _submit();
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
      _pageCtrl.previousPage(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic);
    } else {
      Navigator.of(context).pop();
    }
  }

  bool get _canProceed {
    if (_step == 0) return _relationship != null;
    if (_step == 1) {
      return _nameCtrl.text.trim().length >= 2 &&
             _phoneCtrl.text.replaceAll(' ', '').trim().length >= 7;
    }
    return true;
  }

  Future<void> _submit() async {
    setState(() => _loading = true);

    final fullPhone = '$_dialCode${_phoneCtrl.text.replaceAll(' ', '').trim()}';
    final request = WaliSetupRequest(
      waliName:     _nameCtrl.text.trim(),
      waliPhone:    fullPhone,
      relationship: WaliRelationship.values.firstWhere(
        (r) => r.name == _relationship,
        orElse: () => WaliRelationship.father,
      ),
      permissions: WaliPermissions(
        mustApproveMatches:    _approveMatches,
        canReadMessages:       _readConvos,
        receivesNotifications: _notifications,
        canJoinCalls:          _joinCalls,
      ),
    );

    final repo   = ref.read(waliRepositoryProvider);
    final result = await repo.setup(request);

    setState(() => _loading = false);

    result.when(
      success: (_) {
        // Also send the SMS invitation
        repo.resendInvite();
        if (mounted) {
          ref.read(authProvider.notifier).completeOnboarding();
          context.go(AppRoutes.discovery);
        }
      },
      error: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.message)),
          );
          // Still allow proceeding even if wali setup fails on backend
          ref.read(authProvider.notifier).completeOnboarding();
          context.go(AppRoutes.discovery);
        }
      },
    );
  }

  void _skip() {
    ref.read(authProvider.notifier).completeOnboarding();
    context.go(AppRoutes.discovery);
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _loading,
      child: Scaffold(
        backgroundColor: context.scaffoldColor,
        body: Column(
          children: [
            // ── Gradient header ──────────────────────────────────────────
            _WaliHeader(step: _step, onBack: _back),

            // ── Step dots ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: _StepDots(current: _step, total: 3),
            ),

            // ── Page content ─────────────────────────────────────────────
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics:    const NeverScrollableScrollPhysics(),
                children: [
                  _Step1Relationship(
                    selected: _relationship,
                    onSelect: (r) {
                      HapticFeedback.selectionClick();
                      setState(() => _relationship = r);
                    },
                  ),
                  _Step2Details(
                    nameCtrl:  _nameCtrl,
                    phoneCtrl: _phoneCtrl,
                    dialCode:  _dialCode,
                    flag:      _flag,
                    onCountry: (code, flag) =>
                        setState(() { _dialCode = code; _flag = flag; }),
                    onChanged: () => setState(() {}),
                  ),
                  _Step3Permissions(
                    approveMatches: _approveMatches,
                    readConvos:     _readConvos,
                    notifications:  _notifications,
                    joinCalls:      _joinCalls,
                    onApprove:      (v) => setState(() => _approveMatches = v),
                    onRead:         (v) => setState(() => _readConvos = v),
                    onNotify:       (v) => setState(() => _notifications = v),
                    onCall:         (v) => setState(() => _joinCalls = v),
                  ),
                ],
              ),
            ),

            // ── Bottom buttons ───────────────────────────────────────────
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  children: [
                    MiskButton(
                      label:     _step < 2 ? S.of(context)!.next : S.of(context)!.completeSetup,
                      onPressed: _canProceed ? _next : null,
                      loading:   _loading,
                      icon:      _step < 2
                          ? Icons.arrow_forward_rounded
                          : Icons.shield_rounded,
                    ),
                    const SizedBox(height: 8),
                    MiskButton(
                      label:     S.of(context)!.skipGuardianSetup,
                      onPressed: _skip,
                      variant:   MiskButtonVariant.ghost,
                      small:     true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// GRADIENT HEADER
// ─────────────────────────────────────────────

class _WaliHeader extends StatelessWidget {
  const _WaliHeader({required this.step, required this.onBack});
  final int step;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(top: top),
      decoration: const BoxDecoration(
        gradient: AppColors.roseGradient,
        borderRadius: BorderRadius.only(
          bottomLeft:  Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back button
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded, color: AppColors.white),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 12),
              child: Row(
                children: [
                  // Shield icon
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.goldPrimary.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield_rounded,
                        color: AppColors.goldPrimary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(S.of(context)!.yourGuardian,
                        style: const TextStyle(
                          fontFamily: 'Georgia', fontSize: 22,
                          fontWeight: FontWeight.w700, color: AppColors.white),
                      ),
                      const SizedBox(height: 2),
                      Directionality(
                        textDirection: TextDirection.rtl,
                        child: Text(
                          S.of(context)!.noMarriageWithoutGuardian,
                          style: const TextStyle(
                            fontFamily: 'Scheherazade', fontSize: 16,
                            color: AppColors.goldLight, height: 2.0),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 68, top: 2),
              child: Text(
                S.of(context)!.noMarriageTranslation,
                style: AppTypography.caption.copyWith(
                  color: AppColors.white.withOpacity(0.7),
                  fontStyle: FontStyle.italic, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// STEP DOTS
// ─────────────────────────────────────────────

class _StepDots extends StatelessWidget {
  const _StepDots({required this.current, required this.total});
  final int current, total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i <= current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width:  active ? 24 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: active
                ? AppColors.roseDeep
                : context.isDark ? AppColors.neutral700 : AppColors.neutral300,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────
// STEP 1 — RELATIONSHIP
// ─────────────────────────────────────────────

class _Step1Relationship extends StatelessWidget {
  const _Step1Relationship({
    required this.selected,
    required this.onSelect,
  });
  final String? selected;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.of(context)!.whoIsGuardian,
            style: AppTypography.titleLarge.copyWith(
              fontWeight: FontWeight.w700, color: context.onSurface)),
          const SizedBox(height: 4),
          Text(S.of(context)!.selectRelationship,
            style: AppTypography.bodySmall.copyWith(
              color: context.mutedText, fontSize: 13)),
          const SizedBox(height: 24),

          GridView.count(
            crossAxisCount:  2,
            shrinkWrap:      true,
            physics:         const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              ('father',      S.of(context)!.waliRelFather,      Icons.man_rounded),
              ('brother',     S.of(context)!.waliRelBrother,     Icons.person_rounded),
              ('uncle',       S.of(context)!.waliRelUncle,       Icons.elderly_rounded),
              ('grandfather', S.of(context)!.waliRelGrandfather, Icons.elderly_rounded),
              ('imam',        S.of(context)!.waliRelImam,        Icons.mosque_rounded),
              ('other',       S.of(context)!.waliRelOther,       Icons.group_rounded),
            ].map((r) {
              final (key, label, icon) = r;
              final sel = selected == key;
              return _RelationshipCard(
                label: label, icon: icon, selected: sel,
                onTap: () => onSelect(key),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _RelationshipCard extends StatefulWidget {
  const _RelationshipCard({
    required this.label, required this.icon,
    required this.selected, required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_RelationshipCard> createState() => _RelationshipCardState();
}

class _RelationshipCardState extends State<_RelationshipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceCtrl;
  late final Animation<double>   _bounceAnim;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300));
    _bounceAnim = Tween(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _bounceCtrl, curve: Curves.elasticOut));
  }

  @override
  void didUpdateWidget(_RelationshipCard old) {
    super.didUpdateWidget(old);
    if (widget.selected && !old.selected) {
      _bounceCtrl.forward().then((_) => _bounceCtrl.reverse());
    }
  }

  @override
  void dispose() { _bounceCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _bounceAnim,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: widget.selected ? AppColors.roseGradient : null,
            color:    widget.selected ? null : context.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.selected
                  ? AppColors.roseDeep
                  : context.subtleBg,
              width: widget.selected ? 2 : 1,
            ),
            boxShadow: widget.selected ? [
              BoxShadow(
                color: AppColors.roseDeep.withOpacity(0.2),
                blurRadius: 16, offset: const Offset(0, 4)),
            ] : context.cardShadow,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: widget.selected
                      ? AppColors.white.withOpacity(0.2)
                      : AppColors.roseDeep.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(widget.icon, size: 22,
                  color: widget.selected
                      ? AppColors.white
                      : AppColors.roseDeep),
              ),
              const SizedBox(height: 10),
              Text(widget.label,
                style: AppTypography.labelMedium.copyWith(
                  color:      widget.selected
                      ? AppColors.white
                      : context.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize:   13,
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
// STEP 2 — DETAILS
// ─────────────────────────────────────────────

class _Step2Details extends StatelessWidget {
  const _Step2Details({
    required this.nameCtrl, required this.phoneCtrl,
    required this.dialCode, required this.flag,
    required this.onCountry, required this.onChanged,
  });

  final TextEditingController nameCtrl, phoneCtrl;
  final String dialCode, flag;
  final void Function(String, String) onCountry;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.of(context)!.enterTheirDetails,
            style: AppTypography.titleLarge.copyWith(
              fontWeight: FontWeight.w700, color: context.onSurface)),
          const SizedBox(height: 4),
          Text(S.of(context)!.smsInvitationHint,
            style: AppTypography.bodySmall.copyWith(
              color: context.mutedText, fontSize: 13)),
          const SizedBox(height: 24),

          MiskTextField(
            label:      S.of(context)!.guardianFullName,
            hint:       S.of(context)!.guardianNameHint,
            controller: nameCtrl,
            prefixIcon: const Icon(Icons.person_outline_rounded),
            textInputAction: TextInputAction.next,
            onChanged:  (_) => onChanged(),
            validator: (v) {
              if (v == null || v.trim().length < 2) {
                return S.of(context)!.pleaseEnterGuardianName;
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _showCountryPicker(context),
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.roseLight.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(AppRadius.input),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(flag, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 6),
                      Text(dialCode,
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.onSurface)),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down_rounded,
                          size: 18, color: context.mutedText),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MiskTextField(
                  label:        S.of(context)!.phoneNumber,
                  hint:         S.of(context)!.phoneHint,
                  controller:   phoneCtrl,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  onChanged:    (_) => onChanged(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Info box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.goldLight.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.goldPrimary.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🤲', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'They will receive an SMS invitation to '
                    'join MiskMatch as your guardian. They must '
                    'accept before your matches are approved.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.goldDark, height: 1.6),
                  ),
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms, delay: 200.ms),
        ],
      ),
    );
  }

  void _showCountryPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
      builder: (_) => _WaliCountrySheet(
        onSelect: (code, flag) {
          onCountry(code, flag);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _WaliCountrySheet extends StatefulWidget {
  const _WaliCountrySheet({required this.onSelect});
  final void Function(String, String) onSelect;

  @override
  State<_WaliCountrySheet> createState() => _WaliCountrySheetState();
}

class _WaliCountrySheetState extends State<_WaliCountrySheet> {
  String _q = '';
  static const _countries = [
    ('🇯🇴', 'Jordan', '+962'),       ('🇸🇦', 'Saudi Arabia', '+966'),
    ('🇦🇪', 'UAE', '+971'),          ('🇪🇬', 'Egypt', '+20'),
    ('🇬🇧', 'United Kingdom', '+44'),('🇺🇸', 'United States', '+1'),
    ('🇨🇦', 'Canada', '+1'),         ('🇲🇾', 'Malaysia', '+60'),
    ('🇹🇷', 'Turkey', '+90'),        ('🇩🇪', 'Germany', '+49'),
    ('🇵🇰', 'Pakistan', '+92'),      ('🇮🇳', 'India', '+91'),
    ('🇮🇩', 'Indonesia', '+62'),     ('🇰🇼', 'Kuwait', '+965'),
    ('🇶🇦', 'Qatar', '+974'),        ('🇱🇧', 'Lebanon', '+961'),
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _q.isEmpty
        ? _countries
        : _countries.where((c) =>
            c.$2.toLowerCase().contains(_q.toLowerCase()) ||
            c.$3.contains(_q)).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.6, maxChildSize: 0.85, minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Column(
          children: [
            Container(width: 40, height: 4,
              decoration: BoxDecoration(
                color: context.handleColor,
                borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(S.of(context)!.selectCountry,
              style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            MiskTextField(
              label: S.of(context)!.search, hint: S.of(context)!.countryNameOrCode,
              prefixIcon: const Icon(Icons.search_rounded),
              onChanged: (v) => setState(() => _q = v)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                controller: ctrl,
                itemCount: filtered.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: context.subtleBg),
                itemBuilder: (_, i) {
                  final (flag, name, code) = filtered[i];
                  return ListTile(
                    leading: Text(flag, style: const TextStyle(fontSize: 24)),
                    title: Text(name, style: AppTypography.bodyMedium),
                    trailing: Text(code,
                      style: AppTypography.labelMedium.copyWith(
                        color: context.mutedText)),
                    onTap: () => widget.onSelect(code, flag),
                    contentPadding: EdgeInsets.zero,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// STEP 3 — PERMISSIONS
// ─────────────────────────────────────────────

class _Step3Permissions extends StatelessWidget {
  const _Step3Permissions({
    required this.approveMatches, required this.readConvos,
    required this.notifications, required this.joinCalls,
    required this.onApprove, required this.onRead,
    required this.onNotify, required this.onCall,
  });

  final bool approveMatches, readConvos, notifications, joinCalls;
  final ValueChanged<bool> onApprove, onRead, onNotify, onCall;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.of(context)!.chooseInvolvement,
            style: AppTypography.titleLarge.copyWith(
              fontWeight: FontWeight.w700, color: context.onSurface)),
          const SizedBox(height: 4),
          Text(S.of(context)!.changeSettingsLater,
            style: AppTypography.bodySmall.copyWith(
              color: context.mutedText, fontSize: 13)),
          const SizedBox(height: 24),

          _PermissionRow(
            icon:     Icons.check_circle_rounded,
            label:    S.of(context)!.mustApproveMatches,
            subtitle: S.of(context)!.mustApproveDesc,
            value:    approveMatches,
            onChanged: null, // can't turn off
            isFirst:  true,
          ),
          _PermissionRow(
            icon:     Icons.chat_bubble_outline_rounded,
            label:    S.of(context)!.canReadConversations,
            subtitle: S.of(context)!.canReadDesc,
            value:    readConvos,
            onChanged: onRead,
          ),
          _PermissionRow(
            icon:     Icons.notifications_outlined,
            label:    S.of(context)!.receivesNotifications,
            subtitle: S.of(context)!.receivesNotifDesc,
            value:    notifications,
            onChanged: onNotify,
          ),
          _PermissionRow(
            icon:     Icons.call_outlined,
            label:    S.of(context)!.canJoinCalls,
            subtitle: S.of(context)!.canJoinCallsDesc,
            value:    joinCalls,
            onChanged: onCall,
            isLast:   true,
          ),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon, required this.label, required this.subtitle,
    required this.value, required this.onChanged,
    this.isFirst = false, this.isLast = false,
  });

  final IconData icon;
  final String label, subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool isFirst, isLast;

  @override
  Widget build(BuildContext context) {
    final locked = onChanged == null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.vertical(
          top:    isFirst ? const Radius.circular(16) : Radius.zero,
          bottom: isLast  ? const Radius.circular(16) : Radius.zero,
        ),
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : BorderSide(color: context.subtleBg, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppColors.roseLight.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: AppColors.roseDeep),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                  style: AppTypography.labelMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.onSurface, fontSize: 13)),
                const SizedBox(height: 2),
                Text(subtitle,
                  style: AppTypography.caption.copyWith(
                    color: context.mutedText)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          locked
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.roseDeep.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(S.of(context)!.required,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.roseDeep, fontWeight: FontWeight.w600)),
                )
              : Switch(
                  value:       value,
                  onChanged:   onChanged,
                  activeColor: AppColors.roseDeep,
                  activeTrackColor: AppColors.roseLight,
                ),
        ],
      ),
    );
  }
}
