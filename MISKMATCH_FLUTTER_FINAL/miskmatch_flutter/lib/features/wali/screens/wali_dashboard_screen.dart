import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:miskmatch/l10n/generated/app_localizations.dart';

/// Wali (Guardian) Portal — main dashboard.
///
/// Two roles:
///   A. GUARDIAN — sees wards, decisions, flagged messages, conversations
///   B. WARD    — sees guardian setup status, permissions

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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(waliDashboardProvider);
    final dash  = state.dashboard;

    return Scaffold(
      backgroundColor: context.scaffoldColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          _buildAppBar(context, dash),
        ],
        body: state.isLoading && dash == null
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.goldPrimary, strokeWidth: 2),
              )
            : state.error != null && dash == null
                ? _ErrorState(
                    message: state.error!.message,
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
    final attentionCount = pendingCount + flaggedCount;

    return SliverAppBar(
      pinned:           true,
      floating:         true,
      snap:             true,
      backgroundColor:  context.scaffoldColor,
      elevation:        0,
      surfaceTintColor: Colors.transparent,
      title: Row(
        children: [
          // Gold shield icon box
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
          Text(S.of(context)!.guardianPortal,
            style: const TextStyle(
              fontFamily:  'Georgia',
              fontSize:    20,
              fontWeight:  FontWeight.w700,
              color:       AppColors.goldDark,
            ),
          ),
        ],
      ),
      actions: [
        // "N need attention" red chip
        if (attentionCount > 0)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color:        AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '$attentionCount need attention',
                  style: AppTypography.labelSmall.copyWith(
                    color:      AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        // Refresh
        IconButton(
          icon: Icon(Icons.refresh_rounded,
            color: context.mutedText),
          onPressed: () =>
              ref.read(waliDashboardProvider.notifier).load(),
        ),
      ],
      bottom: dash != null
          ? TabBar(
              controller:           _tabs,
              isScrollable:         true,
              labelColor:           AppColors.goldDark,
              unselectedLabelColor: context.mutedText,
              indicatorColor:       AppColors.goldPrimary,
              indicatorWeight:      2.5,
              labelStyle: AppTypography.labelMedium.copyWith(
                fontWeight: FontWeight.w700),
              unselectedLabelStyle: AppTypography.labelMedium,
              dividerColor:        Colors.transparent,
              tabs: [
                Tab(text: _tabLabel('Decisions',
                    dash.pendingDecisions.where((d) => d.isPending).length)),
                Tab(text: 'Wards (${dash.wards.length})'),
                Tab(text: _tabLabel('Flagged',
                    dash.flaggedMessages.where((m) => !m.reviewed).length)),
                const Tab(text: 'Conversations'),
              ],
            )
          : null,
    );
  }

  String _tabLabel(String base, int count) =>
      count > 0 ? '$base ($count)' : base;
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
        _DecisionsTab(state: state, dash: dash),
        _WardsTab(wards: dash.wards),
        _FlaggedTab(messages: dash.flaggedMessages),
        const _ConversationsTab(),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// TAB 1 — DECISIONS
// ═══════════════════════════════════════════════════════════

class _DecisionsTab extends StatelessWidget {
  const _DecisionsTab({required this.state, required this.dash});
  final WaliDashboardState state;
  final WaliDashboard      dash;

  @override
  Widget build(BuildContext context) {
    final pending = state.undecidedMatches;

    if (pending.isEmpty) {
      return const _EmptyTab(
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

// ═══════════════════════════════════════════════════════════
// TAB 2 — WARDS
// Rose gradient left border, avatar, relationship chip
// ═══════════════════════════════════════════════════════════

class _WardsTab extends StatelessWidget {
  const _WardsTab({required this.wards});
  final List<Ward> wards;

  @override
  Widget build(BuildContext context) {
    if (wards.isEmpty) {
      return const _EmptyTab(
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
// WARD DETAIL SHEET — 65% height
// 60px avatar + name + relationship
// 3 stat boxes, permissions checklist, profile
// ─────────────────────────────────────────────

class _WardDetailSheet extends ConsumerWidget {
  const _WardDetailSheet({required this.ward});
  final Ward ward;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        color:        context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color:        AppColors.neutral300.withOpacity(0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header: avatar + name + relationship ──
                  Row(
                    children: [
                      Container(
                        width: 60, height: 60,
                        decoration: const BoxDecoration(
                          gradient: AppColors.roseGradient,
                          shape:    BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            ward.firstName.isNotEmpty
                                ? ward.firstName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize:   26,
                              color:      AppColors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ward.displayName,
                              style: TextStyle(
                                fontFamily:  'Georgia',
                                fontSize:    20,
                                fontWeight:  FontWeight.w700,
                                color:       context.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(ward.relationship.label,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.roseDeep),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── 3 stat boxes ───────────────────────────
                  Row(
                    children: [
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
                        color: context.mutedText,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Permissions checklist ──────────────────
                  Text(S.of(context)!.permissionsLabel,
                    style: TextStyle(
                      fontFamily:  'Georgia',
                      fontSize:    16,
                      fontWeight:  FontWeight.w700,
                      color:       context.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PermissionRow(
                    label:  S.of(context)!.mustApproveMatches,
                    active: ward.permissions.mustApproveMatches,
                  ),
                  _PermissionRow(
                    label:  S.of(context)!.canReadConversations,
                    active: ward.permissions.canReadMessages,
                  ),
                  _PermissionRow(
                    label:  S.of(context)!.receivesNotifications,
                    active: ward.permissions.receivesNotifications,
                  ),
                  _PermissionRow(
                    label:  S.of(context)!.canJoinCalls,
                    active: ward.permissions.canJoinCalls,
                  ),

                  // ── Profile overview ───────────────────────
                  if (ward.profile != null) ...[
                    const SizedBox(height: 24),
                    Text(S.of(context)!.profileOverview,
                      style: TextStyle(
                        fontFamily:  'Georgia',
                        fontSize:    16,
                        fontWeight:  FontWeight.w700,
                        color:       context.onSurface,
                      ),
                    ),
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
        ],
      ),
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
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(value,
              style: TextStyle(
                fontFamily:  'Georgia',
                fontSize:    28,
                fontWeight:  FontWeight.w700,
                color:       color,
              ),
            ),
            Text(label,
              style: AppTypography.labelSmall.copyWith(color: color),
            ),
          ],
        ),
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
      child: Row(
        children: [
          Icon(
            active
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: active ? AppColors.success : context.mutedText,
            size:  18,
          ),
          const SizedBox(width: 10),
          Text(label,
            style: AppTypography.bodySmall.copyWith(
              color: active ? context.subtleText : context.mutedText,
            ),
          ),
        ],
      ),
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
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text('$label: ',
            style: AppTypography.bodySmall.copyWith(
              color: context.mutedText),
          ),
          Text(value,
            style: AppTypography.bodySmall.copyWith(
              color:      context.subtleText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// TAB 3 — FLAGGED MESSAGES
// ═══════════════════════════════════════════════════════════

class _FlaggedTab extends StatelessWidget {
  const _FlaggedTab({required this.messages});
  final List<FlaggedMessage> messages;

  @override
  Widget build(BuildContext context) {
    final unreviewed = messages.where((m) => !m.reviewed).toList();

    if (unreviewed.isEmpty) {
      return const _EmptyTab(
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

// ═══════════════════════════════════════════════════════════
// TAB 4 — CONVERSATIONS
// People icon rose tint circle, "Ward ↔ Candidate"
// ═══════════════════════════════════════════════════════════

class _ConversationsTab extends ConsumerWidget {
  const _ConversationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convsAsync = ref.watch(waliConversationsProvider);

    return convsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(
          color: AppColors.goldPrimary, strokeWidth: 2),
      ),
      error: (_, __) => const _EmptyTab(
        emoji:   '💬',
        title:   'Conversations unavailable',
        message: 'Could not load conversations. Check your permissions.',
      ),
      data: (convs) {
        if (convs.isEmpty) {
          return const _EmptyTab(
            emoji:   '💬',
            title:   'No conversations to review',
            message: 'Conversations from your wards will appear here '
                     'if you have read permissions enabled.',
          );
        }

        return ListView.separated(
          padding:          const EdgeInsets.symmetric(vertical: 8),
          itemCount:        convs.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            color:  AppColors.neutral300.withOpacity(0.3),
          ),
          itemBuilder: (context, i) => _ConversationTile(conv: convs[i]),
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
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 20, vertical: 8),
      leading: Stack(
        children: [
          // People icon in rose tint circle
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: AppColors.roseDeep.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.people_rounded,
              color: AppColors.roseDeep, size: 22),
          ),
          // Unread badge
          if (conv.unreadCount > 0)
            Positioned(
              right: 0, top: 0,
              child: Container(
                width: 18, height: 18,
                decoration: BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.white, width: 2),
                ),
                child: Center(
                  child: Text('${conv.unreadCount}',
                    style: const TextStyle(
                      fontSize:   9,
                      color:      AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        '${conv.wardName} ↔ ${conv.candidateName}',
        style: AppTypography.titleSmall.copyWith(
          fontWeight: conv.unreadCount > 0
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        conv.lastMessage,
        maxLines:  1,
        overflow:  TextOverflow.ellipsis,
        style: AppTypography.bodySmall.copyWith(
          color: context.mutedText),
      ),
      trailing: Text(
        _ago(conv.lastMessageAt),
        style: AppTypography.labelSmall.copyWith(
          color: conv.unreadCount > 0
              ? AppColors.roseDeep
              : context.mutedText,
        ),
      ),
    );
  }

  String _ago(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24)   return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

// ═══════════════════════════════════════════════════════════
// WARD VIEW — user checking their guardian status
// 3 sub-states: No guardian / Pending / Active
// ═══════════════════════════════════════════════════════════

class _NoGuardianState extends ConsumerWidget {
  const _NoGuardianState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(waliStatusProvider);

    return statusAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(
          color: AppColors.goldPrimary, strokeWidth: 2),
      ),
      error: (_, __) => _NoWaliSetup(onSetup: () {}),
      data: (status) {
        if (!status.hasWali) return _NoWaliSetup(onSetup: () {});
        if (!status.accepted) return _WaliPendingState(status: status);
        return _WaliAcceptedState(status: status);
      },
    );
  }
}

// ─────────────────────────────────────────────
// NO GUARDIAN — 🛡️ 64pt spring scale,
// Arabic hadith gold Scheherazade, setup button
// ─────────────────────────────────────────────

class _NoWaliSetup extends StatelessWidget {
  const _NoWaliSetup({required this.onSetup});
  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🛡️', style: TextStyle(fontSize: 64))
                .animate()
                .scale(
                  begin:    const Offset(0.5, 0.5),
                  end:      const Offset(1.0, 1.0),
                  duration: 600.ms,
                  curve:    Curves.elasticOut,
                ),

            const SizedBox(height: 24),

            Text(
              'No guardian set up yet',
              style: TextStyle(
                fontFamily:  'Georgia',
                fontSize:    24,
                fontWeight:  FontWeight.w700,
                color:       context.subtleText,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            Text(
              "A wali (guardian) is required in Islam for a woman's "
              'marriage. Add your guardian to unlock matches and chats.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color:  context.mutedText,
                height: 1.6,
              ),
            ),

            const SizedBox(height: 20),

            // Arabic hadith
            const ArabicText(
              'لَا نِكَاحَ إِلَّا بِوَلِيٍّ',
              style: TextStyle(
                fontFamily: 'Scheherazade',
                fontSize:   18,
                color:      AppColors.goldPrimary,
                height:     2.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '"There is no marriage without a guardian." — Hadith',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color:     context.mutedText,
                fontStyle: FontStyle.italic,
              ),
            ),

            const SizedBox(height: 36),

            MiskButton(
              label:     'Set up my guardian',
              onPressed: onSetup,
              variant:   MiskButtonVariant.gold,
              icon:      Icons.shield_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PENDING ACCEPTANCE — ⏳ 56pt gentle pulse,
// guardian name, resend button
// ─────────────────────────────────────────────

class _WaliPendingState extends ConsumerWidget {
  const _WaliPendingState({required this.status});
  final WaliStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⏳', style: TextStyle(fontSize: 56))
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 1.0, end: 1.06, duration: 1500.ms),

            const SizedBox(height: 24),

            Text(
              'Waiting for guardian to accept',
              style: TextStyle(
                fontFamily:  'Georgia',
                fontSize:    22,
                fontWeight:  FontWeight.w600,
                color:       context.subtleText,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            if (status.waliName != null)
              Text(
                '${status.waliName} has been sent an SMS invitation. '
                'They will join MiskMatch as your guardian in sha Allah.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color:  context.mutedText,
                  height: 1.6,
                ),
              ),

            const SizedBox(height: 32),

            MiskButton(
              label: 'Resend invitation',
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
              variant: MiskButtonVariant.outline,
              icon:    Icons.send_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// GUARDIAN ACTIVE — ✓ 80px success circle,
// shield 40pt, elastic scale, permissions table
// ─────────────────────────────────────────────

class _WaliAcceptedState extends StatelessWidget {
  const _WaliAcceptedState({required this.status});
  final WaliStatus status;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 80px success circle with shield
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color:  AppColors.success.withOpacity(0.1),
                shape:  BoxShape.circle,
                border: Border.all(
                  color: AppColors.success.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: const Icon(Icons.shield_rounded,
                color: AppColors.success, size: 40),
            )
                .animate()
                .scale(
                  begin:    const Offset(0.5, 0.5),
                  end:      const Offset(1.0, 1.0),
                  duration: 600.ms,
                  curve:    Curves.elasticOut,
                ),

            const SizedBox(height: 24),

            Text(
              'Guardian active',
              style: TextStyle(
                fontFamily:  'Georgia',
                fontSize:    22,
                fontWeight:  FontWeight.w700,
                color:       context.onSurface,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            if (status.waliName != null)
              Text(
                '${status.waliName} '
                '(${status.relationship?.label ?? 'Guardian'}) '
                'is your active wali. They are notified of all match activity.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color:  context.mutedText,
                  height: 1.6,
                ),
              ),

            const SizedBox(height: 32),

            // Permissions table — 4 rows
            Container(
              width:   double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:        context.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow:    context.cardShadow,
              ),
              child: Column(
                children: [
                  _PermRow('Must approve matches',
                      status.permissions.mustApproveMatches),
                  _PermRow('Can read conversations',
                      status.permissions.canReadMessages),
                  _PermRow('Receives notifications',
                      status.permissions.receivesNotifications),
                  _PermRow('Can join calls',
                      status.permissions.canJoinCalls),
                ],
              ),
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
      child: Row(
        children: [
          Icon(
            active
                ? Icons.check_circle_rounded
                : Icons.circle_outlined,
            size:  16,
            color: active ? AppColors.success : context.mutedText,
          ),
          const SizedBox(width: 10),
          Text(label,
            style: AppTypography.bodySmall.copyWith(
              color: context.subtleText),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// SHARED EMPTY + ERROR STATES
// ═══════════════════════════════════════════════════════════

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
              style: TextStyle(
                fontFamily:  'Georgia',
                fontSize:    20,
                fontWeight:  FontWeight.w600,
                color:       context.subtleText,
              ),
              textAlign: TextAlign.center,
            ).animate(delay: 100.ms).fadeIn(duration: 400.ms),
            const SizedBox(height: 8),
            Text(message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color:  context.mutedText,
                height: 1.6,
              ),
            ).animate(delay: 200.ms).fadeIn(duration: 400.ms),
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
            Text(message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: context.mutedText),
            ),
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
