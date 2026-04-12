import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/l10n/generated/app_localizations.dart';
import 'package:miskmatch/features/profile/data/profile_models.dart';
import '../providers/discovery_provider.dart';

/// Shows the discovery filter bottom sheet. Returns true if filters were applied.
Future<bool?> showFilterSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FilterSheet(ref: ref),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.ref});
  final WidgetRef ref;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late RangeValues _ageRange;
  String? _country;
  String? _madhab;
  String? _prayer;

  @override
  void initState() {
    super.initState();
    final current = widget.ref.read(discoveryFiltersProvider);
    _ageRange = RangeValues(
      current.minAge?.toDouble() ?? 18,
      current.maxAge?.toDouble() ?? 60,
    );
    _country = current.country;
    _madhab = current.madhab;
    _prayer = current.prayer;
  }

  void _reset() {
    HapticFeedback.lightImpact();
    setState(() {
      _ageRange = const RangeValues(18, 60);
      _country = null;
      _madhab = null;
      _prayer = null;
    });
  }

  void _apply() {
    HapticFeedback.mediumImpact();
    final isDefault = _ageRange.start == 18 &&
        _ageRange.end == 60 &&
        _country == null &&
        _madhab == null &&
        _prayer == null;

    widget.ref.read(discoveryFiltersProvider.notifier).state = DiscoveryFilters(
      minAge: isDefault ? null : _ageRange.start.round(),
      maxAge: isDefault ? null : _ageRange.end.round(),
      country: _country,
      madhab: _madhab,
      prayer: _prayer,
    );
    widget.ref.read(discoveryProvider.notifier).refresh();
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: context.mutedText.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header row
              Row(
                children: [
                  Text(l.filters,
                    style: AppTypography.headlineSmall.copyWith(
                      color: context.subtleText,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _reset,
                    child: Text(l.resetFilters,
                      style: TextStyle(color: AppColors.roseDeep)),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Age range slider ────────────────────────────
              Text(l.ageRange,
                style: AppTypography.labelMedium.copyWith(
                  color: context.subtleText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text('${_ageRange.start.round()}',
                    style: AppTypography.bodySmall.copyWith(
                      color: context.mutedText)),
                  Expanded(
                    child: RangeSlider(
                      values: _ageRange,
                      min: 18,
                      max: 60,
                      divisions: 42,
                      activeColor: AppColors.roseDeep,
                      inactiveColor: AppColors.roseDeep.withOpacity(0.15),
                      labels: RangeLabels(
                        '${_ageRange.start.round()}',
                        '${_ageRange.end.round()}',
                      ),
                      onChanged: (v) => setState(() => _ageRange = v),
                    ),
                  ),
                  Text('${_ageRange.end.round()}',
                    style: AppTypography.bodySmall.copyWith(
                      color: context.mutedText)),
                ],
              ),
              const SizedBox(height: 20),

              // ── Country dropdown ────────────────────────────
              _FilterDropdown(
                label: l.anyCountry,
                value: _country,
                items: _countries,
                onChanged: (v) => setState(() => _country = v),
              ),
              const SizedBox(height: 14),

              // ── Madhab dropdown ────────────────────────────
              _FilterDropdown(
                label: l.anyMadhab,
                value: _madhab,
                items: {
                  for (final m in Madhab.values)
                    m.value: m.localizedLabel(l),
                },
                onChanged: (v) => setState(() => _madhab = v),
              ),
              const SizedBox(height: 14),

              // ── Prayer dropdown ────────────────────────────
              _FilterDropdown(
                label: l.anyPrayer,
                value: _prayer,
                items: {
                  for (final p in PrayerFrequency.values)
                    p.value: p.localizedLabel(l),
                },
                onChanged: (v) => setState(() => _prayer = v),
              ),
              const SizedBox(height: 24),

              // ── Apply button ────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _apply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.roseDeep,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(l.applyFilters,
                    style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
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
// FILTER DROPDOWN
// ─────────────────────────────────────────────

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final Map<String, String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: context.subtleBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value != null
              ? AppColors.roseDeep.withOpacity(0.4)
              : context.mutedText.withOpacity(0.15),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isExpanded: true,
          hint: Text(label,
            style: AppTypography.bodyMedium.copyWith(
              color: context.mutedText)),
          icon: Icon(Icons.keyboard_arrow_down_rounded,
            color: context.mutedText),
          dropdownColor: context.surfaceColor,
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(label,
                style: AppTypography.bodyMedium.copyWith(
                  color: context.mutedText)),
            ),
            ...items.entries.map((e) => DropdownMenuItem<String?>(
              value: e.key,
              child: Text(e.value,
                style: AppTypography.bodyMedium.copyWith(
                  color: context.subtleText)),
            )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// COMMON COUNTRIES (top markets)
// ─────────────────────────────────────────────

const _countries = <String, String>{
  'SA': 'Saudi Arabia',
  'AE': 'UAE',
  'JO': 'Jordan',
  'EG': 'Egypt',
  'GB': 'United Kingdom',
  'US': 'United States',
  'CA': 'Canada',
  'MY': 'Malaysia',
  'ID': 'Indonesia',
  'PK': 'Pakistan',
  'TR': 'Turkey',
  'KW': 'Kuwait',
  'QA': 'Qatar',
  'BH': 'Bahrain',
  'OM': 'Oman',
};
