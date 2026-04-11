import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:miskmatch/core/router/app_router.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';

/// Main app shell — wraps the bottom navigation bar around
/// the discovery, match list, wali portal, and profile screens.

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    _TabItem(
      icon:        Icons.explore_outlined,
      activeIcon:  Icons.explore_rounded,
      label:       'Discover',
      labelAr:     'اكتشاف',
      route:       AppRoutes.discovery,
    ),
    _TabItem(
      icon:        Icons.favorite_outline_rounded,
      activeIcon:  Icons.favorite_rounded,
      label:       'Matches',
      labelAr:     'المطابقات',
      route:       AppRoutes.matches,
    ),
    _TabItem(
      icon:        Icons.shield_outlined,
      activeIcon:  Icons.shield_rounded,
      label:       'Guardian',
      labelAr:     'الولي',
      route:       AppRoutes.wali,
    ),
    _TabItem(
      icon:        Icons.person_outline_rounded,
      activeIcon:  Icons.person_rounded,
      label:       'Profile',
      labelAr:     'الملف',
      route:       AppRoutes.profile,
    ),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].route)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex(context);

    return Scaffold(
      body:  child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: context.surfaceColor,
          boxShadow: [
            BoxShadow(
              color:      AppColors.roseDeep.withOpacity(0.08),
              blurRadius: 20,
              offset:     const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final tab      = _tabs[i];
                final selected = i == currentIndex;
                return Expanded(
                  child: _NavTab(
                    tab:      tab,
                    selected: selected,
                    onTap:    () => context.go(tab.route),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final _TabItem     tab;
  final bool         selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      child: GestureDetector(
        onTap:     onTap,
        behavior:  HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve:    Curves.easeOutCubic,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  selected ? tab.activeIcon : tab.icon,
                  key:   ValueKey(selected),
                  color: color,
                  size:  24,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tab.label,
                style: AppTypography.labelSmall.copyWith(
                  color:      color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.labelAr,
    required this.route,
  });

  final IconData icon;
  final IconData activeIcon;
  final String   label;
  final String   labelAr;
  final String   route;
}
