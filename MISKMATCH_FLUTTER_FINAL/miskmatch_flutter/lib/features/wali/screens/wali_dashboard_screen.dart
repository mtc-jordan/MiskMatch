import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/wali_models.dart';
import '../data/wali_repository.dart';
import '../providers/wali_provider.dart';
import '../widgets/decision_card.dart';
import '../widgets/wali_widgets.dart';
import 'package:miskmatch/features/auth/providers/auth_provider.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/shared/widgets/common_widgets.dart';

/// Wali (Guardian) Portal — main dashboard.
///
/// Two roles land here:
///   A. THE GUARDIAN themselves — sees their wards, pending decisions,
///      flagged messages, chaperoned conversations.
///   B. A WARD — sees their guardian setup status, permissions,
///      option to resend invite or add a guardian.
///
/// The screen detects which role via the user's auth role.

class WaliDashboardScreen extends ConsumerStatefulWidget {
  const WaliDashboardScreen({super.key});

  @override
  ConsumerState<WaliDashboardScreen> createState() =>
      _WaliDashboardScreenState();
}

class _WaliDashboardScreenState
    extends ConsumerState<WaliDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  // 0 = Decisions, 1 = Wards, 2 = Messages, 3 = Conversations

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(waliDashboardProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  bool get _isWali {
    final auth = ref.read(authProvider);
    if (auth is AuthAuthenticated) {
      // In a real app, check user.role == 'wali'
      // For now, check if they have wards (dashboard loaded)
      final dash = ref.read(waliDashboardProvider).dashboard;
      return dash != null && dash.wards.isNotEmpty;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(waliDashboardProvider);
    final dash  = state.dashboard;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          _buildAppBar(context, dash),
        ],
        body: state.isLoading && dash == null
            ? const Center(child: CircularProgressIndicator(
                color: AppColors.roseDeep, strokeWidth: 2))
            : state.error != null && dash == null
                ? _ErrorState(
                    message:  state.error!.message,
                    onRetry: () =>
                        ref.read(waliDashboardProvider.notifier).load(),
                  )
                : dash == null
                    ? const _NoGuardianState()
                    : _DashboardTabs(
                        tabs:  _tabs,
                        state: state,
                        dash:  dash,
                      ),
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, WaliDashboard? dash) {
    final pendingCount = dash?.pendingDecisions
        .where((d) => d.isPending)
        .length ?? 0;
    final flaggedCount = dash?.flaggedMessages
        .where((m) => !m.reviewed)
        .length ?? 0;

    return SliverAppBar(
      pinned:          true,
      floating:        true,
      snap:            true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation:       0,
      title: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color:        AppColors.goldPrimary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.shield_rounded,
              color: AppColors.goldPrimary, size: 20),
        ),
        const SizedBox(width: 10),
        Text('Guardian Portal',
            style: AppTypography.titleLarge.copyWith(
              color: AppColors.goldDark, fontWeight: FontWeight.w700)),
      ]),
      actions: [
        if (pendingCount > 0 || flaggedCount > 0)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color:        AppColors.error.withOpacity(0.1),
                borderRadius: AppRadius.chipRadius,
              ),
              child: Text(
                '${pendingCount + flaggedCount} need attention',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.error, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        IconButton(
          icon:      const Icon(Icons.refresh_rounded),
          color:     AppColors.neutral500,
          onPressed: () =>
              ref.read(waliDashboardProvider.notifier).load(),
        ),
      ],
      bottom: dash != null
          ? TabBar(
              controller:          _tabs,
              isScrollable:        true,
              labelColor:          AppColors.goldDark,
              unselectedLabelColor:AppColors.neutral500,
              indicatorColor:      AppColors.goldPrimary,
              indicatorWeight:     2.5,
              labelStyle:          AppTypography.labelMedium.copyWith(
                fontWeight: FontWeight.w600),
              unselectedLabelStyle:AppTypography.labelMedium,
              tabs: [
                Tab(text: _pendingLabel(dash)),
                Tab(text: 'Wards (${dash.wards.length})'),
                Tab(text: _flaggedLabel(dash)),
                const Tab(text: 'Conversations'),
              ],
            )
          : null,
    );
  }

  String _pendingLabel(WaliDashboard dash) {
    final count = dash.pendingDecisions.where((d) => d.isPending).length;
    return count > 0 ? 'Decisions ($count)' : 'Decisions';
  }

  String _flaggedLabel(WaliDashboard dash) {
    final count = dash.flaggedMessages.where((m) => !m.reviewed).length;
    return count > 0 ? 'Flagged ($count)' : 'Flagged';
  }
}

// ─────────────────────────────────────────────
// DASHBOARD TABS
// ─────────────────────────────────────────────

class _DashboardTabs extends ConsumerWidget {
  const _DashboardTabs({
    required this.tabs,
    required this.state,
    required this.dash,
  });

  final TabController      tabs;
  final WaliDashboardState state;
  final WaliDashboard      dash;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TabBarView(
      controller: tabs,
      children: [
        // Tab 0 — Pending decisions
        _DecisionsTab(state: state, dash: dash),
        // Tab 1 — Wards
        _WardsTab(wards: dash.wards),
        // Tab 2 — Flagged messages
        _FlaggedTab(messages: dash.flaggedMessages),
        // Tab 3 — Conversations
        _ConversationsTab(),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// TAB: DECISIONS
// ─────────────────────────────────────────────

class _DecisionsTab extends StatelessWidget {
  const _DecisionsTab({required this.state, required this.dash});
  final WaliDashboardState state;
  final WaliDashboard      dash;

  @override
  Widget build(BuildContext context) {
    final pending = state.undecidedMatches;

    if (pending.isEmpty) {
      return _EmptyTab(
        emoji:   '✅',
        title:   'No pending decisions',
        message: 'All match requests have been reviewed. '
                 'JazakAllah Khair for your diligence.',
      );
    }

    return ListView.builder(
      padding:     const EdgeInsets.only(top: 16, bottom: 40),
      itemCount:   pending.length,
      itemBuilder: (context, i) => DecisionCard(
        decision: pending[i],
        index:    i,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TAB: WARDS
// ─────────────────────────────────────────────

class _WardsTab extends StatelessWidget {
  const _WardsTab({required this.wards});
  final List<Ward> wards;

  @override
  Widget build(BuildContext context) {
    if (wards.isEmpty) {
      return _EmptyTab(
        emoji:   '👥',
        title:   'No wards yet',
        message: 'When someone adds you as their guardian, '
                 'they will appear here.',
      );
    }

    return ListView.builder(
      padding:     const EdgeInsets.only(top: 16, bottom: 40),
      itemCount:   wards.length,
      itemBuilder: (context, i) => WardSummaryCard(
        ward:  wards[i],
        index: i,
        onTap: () => _showWardDetail(context, wards[i]),
      ),
    );
  }

  void _showWardDetail(BuildContext context, Ward ward) {
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder:            (_) => _WardDetailSheet(ward: ward),
    );
  }
}

// ─────────────────────────────────────────────
// WARD DETAIL SHEET
// ─────────────────────────────────────────────

class _WardDetailSheet extends ConsumerWidget {
  const _WardDetailSheet({required this.ward});
  final Ward ward;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      height:     MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        color:        theme.colorScheme.surface,
        borderRadius: AppRadius.bottomSheet,
      ),
      child: Column(children: [
        Container(
          margin:  const EdgeInsets.only(top: 12, bottom: 8),
          width:   40, height: 4,
          decoration: BoxDecoration(
            color:        theme.colorScheme.outline.withOpacity(0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(children: [
                  Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      gradient: AppColors.roseGradient,
                      shape:    BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        ward.firstName.isNotEmpty
                            ? ward.firstName[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize:   26,
                          color:      AppColors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ward.displayName,
                          style: AppTypography.headlineSmall.copyWith(
                            fontWeight: FontWeight.w700)),
                      Text(ward.relationship.label,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.roseDeep)),
                    ],
                  )),
                ]),

                const SizedBox(height: 24),

                // Stats
                Row(children: [
                  _StatBox(
                    label: 'Pending',
                    value: '${ward.pendingDecisions}',
                    color: ward.pendingDecisions > 0
                        ? AppColors.error
                        : AppColors.success,
                  ),
                  const SizedBox(width: 12),
                  _StatBox(
                    label: 'Active',
                    value: '${ward.activeMatches}',
                    color: AppColors.roseDeep,
                  ),
                  const SizedBox(width: 12),
                  _StatBox(
                    label: 'Since',
                    value: ward.joinedAt != null
                        ? '${ward.joinedAt!.day}/${ward.joinedAt!.month}'
                        : '—',
                    color: AppColors.neutral500,
                  ),
                ]),

                const SizedBox(height: 24),

                // Permissions section
                Text('Permissions',
                    style: AppTypography.titleSmall),
                const SizedBox(height: 12),
                _PermissionRow(
                  label: 'Must approve matches',
                  active: ward.permissions.mustApproveMatches,
                ),
                _PermissionRow(
                  label: 'Can read conversations',
                  active: ward.permissions.canReadMessages,
                ),
                _PermissionRow(
                  label: 'Receives notifications',
                  active: ward.permissions.receivesNotifications,
                ),
                _PermissionRow(
                  label: 'Can join chaperoned calls',
                  active: ward.permissions.canJoinCalls,
                ),

                const SizedBox(height: 24),

                // Profile summary if available
                if (ward.profile != null) ...[
                  Text('Profile overview',
                      style: AppTypography.titleSmall),
                  const SizedBox(height: 12),
                  if (ward.profile!.prayerFrequency != null)
                    _InfoRow(
                      icon:  '🕌',
                      label: 'Prayer',
                      value: ward.profile!.prayerLabel,
                    ),
                  if (ward.profile!.madhab != null)
                    _InfoRow(
                      icon:  '📚',
                      label: 'Madhab',
                      value: ward.profile!.madhabLabel,
                    ),
                  if (ward.profile!.city != null)
                    _InfoRow(
                      icon:  '📍',
                      label: 'Location',
                      value: ward.profile!.locationText,
                    ),
                ],
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color:        color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(children: [
          Text(value,
              style: AppTypography.headlineMedium.copyWith(
                color:      color,
                fontWeight: FontWeight.w700,
                fontSize:   28,
              )),
          Text(label,
              style: AppTypography.labelSmall.copyWith(color: color)),
        ]),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.label, required this.active});
  final String label;
  final bool   active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(
          active ? Icons.check_circle_rounded : Icons.cancel_outlined,
          color: active ? AppColors.success : AppColors.neutral400,
          size: 18,
        ),
        const SizedBox(width: 10),
        Text(label,
            style: AppTypography.bodySmall.copyWith(
              color: active ? AppColors.neutral700 : AppColors.neutral500,
            )),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final String icon, label, value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Text('$label: ',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.neutral500)),
        Text(value,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.neutral700, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

extension on AppColors {
  static const neutral400 = Color(0xFFAAAAAA);
}

// ─────────────────────────────────────────────
// TAB: FLAGGED MESSAGES
// ─────────────────────────────────────────────

class _FlaggedTab extends StatelessWidget {
  const _FlaggedTab({required this.messages});
  final List<FlaggedMessage> messages;

  @override
  Widget build(BuildContext context) {
    final unreviewed = messages.where((m) => !m.reviewed).toList();

    if (unreviewed.isEmpty) {
      return _EmptyTab(
        emoji:   '✅',
        title:   'No flagged messages',
        message: 'All conversations are within Islamic guidelines. '
                 'Alhamdulillah.',
      );
    }

    return ListView.builder(
      padding:     const EdgeInsets.only(top: 16, bottom: 40),
      itemCount:   unreviewed.length,
      itemBuilder: (context, i) => FlaggedMessageCard(
        message: unreviewed[i],
        index:   i,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TAB: CONVERSATIONS
// ─────────────────────────────────────────────

class _ConversationsTab extends ConsumerWidget {
  const _ConversationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convsAsync = ref.watch(waliConversationsProvider);

    return convsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(
          color: AppColors.roseDeep, strokeWidth: 2)),
      error: (_, __) => _EmptyTab(
        emoji:   '💬',
        title:   'Conversations unavailable',
        message: 'Could not load conversations. Check your permissions.',
      ),
      data: (convs) {
        if (convs.isEmpty) {
          return _EmptyTab(
            emoji:   '💬',
            title:   'No conversations to review',
            message: 'Conversations from your wards will appear here '
                     'if you have read permissions enabled.',
          );
        }

        return ListView.separated(
          padding:          const EdgeInsets.symmetric(vertical: 8),
          itemCount:        convs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder:      (context, i) => _ConversationTile(conv: convs[i]),
        );
      },
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conv});
  final WaliConversation conv;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.roseDeep.withOpacity(0.15),
            child: const Icon(Icons.people_rounded,
                color: AppColors.roseDeep, size: 22),
          ),
          if (conv.unreadCount > 0)
            Positioned(
              right: 0, top: 0,
              child: Container(
                width: 16, height: 16,
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text('${conv.unreadCount}',
                      style: const TextStyle(
                        fontSize: 9, color: AppColors.white,
                        fontWeight: FontWeight.w700,
                      )),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        '${conv.wardName} ↔ ${conv.candidateName}',
        style: AppTypography.titleSmall,
      ),
      subtitle: Text(
        conv.lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.bodySmall.copyWith(color: AppColors.neutral500),
      ),
      trailing: Text(
        _ago(conv.lastMessageAt),
        style: AppTypography.labelSmall.copyWith(
          color: AppColors.neutral500),
      ),
      onTap: () {
        // Navigate to read-only message view
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Read-only conversation view — Sprint 6'),
          ),
        );
      },
    );
  }

  String _ago(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24)   return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

// ─────────────────────────────────────────────
// NO GUARDIAN STATE  (ward view — not set up)
// ─────────────────────────────────────────────

class _NoGuardianState extends ConsumerWidget {
  const _NoGuardianState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(waliStatusProvider);

    return statusAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(
          color: AppColors.goldPrimary, strokeWidth: 2)),
      error: (_, __) => _NoWaliSetup(onSetup: () {}),
      data: (status) {
        if (!status.hasWali) return _NoWaliSetup(onSetup: () {});
        if (!status.accepted) return _WaliPendingState(status: status);
        return _WaliAcceptedState(status: status);
      },
    );
  }
}

class _NoWaliSetup extends StatelessWidget {
  const _NoWaliSetup({required this.onSetup});
  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🛡️', style: TextStyle(fontSize: 64))
                .animate().scale(
                    begin:    const Offset(0.6, 0.6),
                    duration: 500.ms,
                    curve:    Curves.elasticOut),
            const SizedBox(height: 24),
            Text('No guardian set up yet',
                style: AppTypography.headlineSmall.copyWith(
                  color: AppColors.neutral700),
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(
              'A wali (guardian) is required in Islam for a woman\'s '
              'marriage. Add your guardian to unlock matches and chats.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color:  AppColors.neutral500,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 12),
            const ArabicText(
              'لَا نِكَاحَ إِلَّا بِوَلِيٍّ',
              style: TextStyle(
                fontFamily: 'Scheherazade',
                fontSize:   18,
                color:      AppColors.goldPrimary,
                height:     2.0,
              ),
            ),
            Text(
              '"There is no marriage without a guardian." — Hadith',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.neutral500, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 36),
            MiskButton(
              label:    'Set up my guardian',
              onPressed: onSetup,
              icon:     Icons.shield_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

class _WaliPendingState extends ConsumerWidget {
  const _WaliPendingState({required this.status});
  final WaliStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⏳', style: TextStyle(fontSize: 64))
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 1.0, end: 1.06, duration: 1500.ms),
            const SizedBox(height: 24),
            Text('Waiting for guardian to accept',
                style: AppTypography.headlineSmall.copyWith(
                  color: AppColors.neutral700),
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            if (status.waliName != null)
              Text(
                '${status.waliName} has been sent an SMS invitation. '
                'They will join MiskMatch as your guardian in sha Allah.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color:  AppColors.neutral500,
                  height: 1.6,
                ),
              ),
            const SizedBox(height: 32),
            MiskButton(
              label:    'Resend invitation',
              onPressed: () async {
                await ref.read(waliRepositoryProvider).resendInvite();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invitation resent. JazakAllah Khair.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
              variant:  MiskButtonVariant.outline,
              icon:     Icons.send_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

class _WaliAcceptedState extends StatelessWidget {
  const _WaliAcceptedState({required this.status});
  final WaliStatus status;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color:  AppColors.success.withOpacity(0.1),
                shape:  BoxShape.circle,
                border: Border.all(
                  color: AppColors.success.withOpacity(0.3), width: 2),
              ),
              child: const Icon(Icons.shield_rounded,
                  color: AppColors.success, size: 40),
            )
                .animate()
                .scale(begin: const Offset(0.7, 0.7),
                    duration: 500.ms, curve: Curves.elasticOut),
            const SizedBox(height: 24),
            Text('Guardian active',
                style: AppTypography.headlineSmall.copyWith(
                  color: AppColors.neutral900),
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            if (status.waliName != null)
              Text(
                '${status.waliName} (${status.relationship?.label ?? 'Guardian'}) '
                'is your active wali. They are notified of all match activity.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.neutral500, height: 1.6),
              ),
            const SizedBox(height: 32),
            MiskCard(
              child: Column(children: [
                _PermRow('Must approve matches', status.permissions.mustApproveMatches),
                _PermRow('Can read conversations', status.permissions.canReadMessages),
                _PermRow('Receives notifications', status.permissions.receivesNotifications),
                _PermRow('Can join calls', status.permissions.canJoinCalls),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermRow extends StatelessWidget {
  const _PermRow(this.label, this.active);
  final String label;
  final bool   active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(
          active ? Icons.check_circle_rounded : Icons.circle_outlined,
          size: 16,
          color: active ? AppColors.success : AppColors.neutral400,
        ),
        const SizedBox(width: 10),
        Text(label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.neutral700)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// SHARED EMPTY + ERROR STATES
// ─────────────────────────────────────────────

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({
    required this.emoji,
    required this.title,
    required this.message,
  });
  final String emoji, title, message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 48))
                .animate().fadeIn(duration: 400.ms),
            const SizedBox(height: 16),
            Text(title,
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.neutral700),
                textAlign: TextAlign.center)
                .animate(delay: 100.ms).fadeIn(),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color:  AppColors.neutral500,
                  height: 1.6,
                ))
                .animate(delay: 200.ms).fadeIn(),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String       message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 48, color: AppColors.neutral300),
            const SizedBox(height: 20),
            Text(message, textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.neutral500)),
            const SizedBox(height: 24),
            MiskButton(
              label:     'Try again',
              onPressed: onRetry,
              variant:   MiskButtonVariant.outline,
              fullWidth: false,
              icon:      Icons.refresh_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

extension on AppColors {
  static const neutral400 = Color(0xFFAAAAAA);
}
