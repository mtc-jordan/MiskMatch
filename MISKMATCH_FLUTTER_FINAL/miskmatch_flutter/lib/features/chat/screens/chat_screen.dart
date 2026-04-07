import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input_bar.dart';
import 'package:miskmatch/features/match/data/match_models.dart';
import 'package:miskmatch/features/match/providers/match_provider.dart';
import 'package:miskmatch/features/auth/providers/auth_provider.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/shared/widgets/common_widgets.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.matchId});
  final String matchId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollCtrl = ScrollController();
  bool  _atBottom   = true;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    // Scroll to bottom after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scrollCtrl.position;
    setState(() {
      _atBottom = pos.pixels >= pos.maxScrollExtent - 120;
    });
    // Load more when scrolled to top
    if (pos.pixels <= 100) {
      ref.read(chatProvider(widget.matchId).notifier).loadMore();
    }
  }

  void _scrollToBottom({bool animate = false}) {
    if (!_scrollCtrl.hasClients) return;
    if (animate) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve:    Curves.easeOut,
      );
    } else {
      _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
    }
  }

  String get _myUserId {
    final auth = ref.read(authProvider);
    return auth is AuthAuthenticated ? auth.userId : '';
  }

  @override
  Widget build(BuildContext context) {
    final chat   = ref.watch(chatProvider(widget.matchId));
    final match  = ref.watch(matchDetailProvider(widget.matchId));
    final theme  = Theme.of(context);

    // Auto-scroll on new messages
    ref.listen(chatProvider(widget.matchId), (prev, next) {
      if (prev != null &&
          next.messages.length > prev.messages.length &&
          _atBottom) {
        WidgetsBinding.instance.addPostFrameCallback(
            (_) => _scrollToBottom(animate: true));
      }
    });

    final otherProfile = match.valueOrNull?.otherProfile(_myUserId);
    final otherName    = otherProfile?.displayFirstName ?? 'Match';
    final isActive     = match.valueOrNull?.status.canChat ?? false;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(context, otherName, otherProfile, chat, match),
      body: Column(
        children: [
          // ── Wali approval banner ─────────────────────────────────────
          if (match.hasValue && match.value!.status.needsWali)
            _WaliApprovalBanner(match: match.value!),

          // ── Moderation alert ─────────────────────────────────────────
          if (chat.moderationAlert != null)
            _ModerationAlert(
              message: chat.moderationAlert!,
              onDismiss: () => ref
                  .read(chatProvider(widget.matchId).notifier)
                  .clearModerationAlert(),
            ),

          // ── Message list ─────────────────────────────────────────────
          Expanded(
            child: chat.isLoading && chat.messages.isEmpty
                ? const _ChatLoading()
                : _MessageList(
                    groups:     chat.grouped,
                    myUserId:   _myUserId,
                    scrollCtrl: _scrollCtrl,
                    matchId:    widget.matchId,
                  ),
          ),

          // ── Typing indicator ─────────────────────────────────────────
          if (chat.anyoneTyping)
            TypingIndicator(userName: otherName),

          // ── Scroll-to-bottom FAB ──────────────────────────────────────
          if (!_atBottom)
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16, bottom: 4),
                child: FloatingActionButton.small(
                  onPressed: () => _scrollToBottom(animate: true),
                  backgroundColor: AppColors.roseDeep,
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppColors.white),
                ),
              ),
            ),

          // ── Input bar ────────────────────────────────────────────────
          SafeArea(
            top: false,
            child: ChatInputBar(
              disabled:     !isActive,
              onSendText:   (text) => ref
                  .read(chatProvider(widget.matchId).notifier)
                  .sendText(text),
              onSendVoice:  (path) => ref
                  .read(chatProvider(widget.matchId).notifier)
                  .sendVoice(path),
              onTyping:     (text) => ref
                  .read(chatProvider(widget.matchId).notifier)
                  .onTextChanged(text),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    String       otherName,
    dynamic      otherProfile,
    ChatState    chat,
    AsyncValue<Match> match,
  ) {
    final isOnline = chat.onlineUsers.isNotEmpty;

    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      scrolledUnderElevation: 1,
      leading: const BackButton(),
      titleSpacing: 0,
      title: Row(
        children: [
          // Avatar
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.roseDeep,
                child: Text(
                  otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isOnline)
                Positioned(
                  right: 0, bottom: 0,
                  child: Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color:  AppColors.success,
                      shape:  BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(otherName, style: AppTypography.titleSmall),
              Text(
                isOnline ? 'Online' : 'Last seen recently',
                style: AppTypography.labelSmall.copyWith(
                  color: isOnline ? AppColors.success : AppColors.neutral500,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon:    const Icon(Icons.videocam_outlined),
          tooltip: 'Chaperoned call',
          onPressed: () {}, // Sprint 5 — calls
        ),
        IconButton(
          icon:    const Icon(Icons.more_vert_rounded),
          onPressed: () {}, // TODO: match options
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// MESSAGE LIST
// ─────────────────────────────────────────────

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.groups,
    required this.myUserId,
    required this.scrollCtrl,
    required this.matchId,
  });

  final List<MessageGroup> groups;
  final String             myUserId;
  final ScrollController   scrollCtrl;
  final String             matchId;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return const _EmptyChatState();
    }

    // Flatten into a single scrollable list with date separators
    final items = <_ChatItem>[];
    for (final group in groups) {
      items.add(_ChatItem.dateSeparator(group.date));
      for (var i = 0; i < group.messages.length; i++) {
        items.add(_ChatItem.message(group.messages[i]));
      }
    }

    return ListView.builder(
      controller:  scrollCtrl,
      padding:     const EdgeInsets.only(top: 8, bottom: 8),
      itemCount:   items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item.isDivider) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: _DateDivider(date: item.date!),
            ),
          );
        }
        final msg  = item.message!;
        final isMe = msg.senderId == myUserId;
        // Show timestamp on first message or when gap > 5 min
        final showTs = index == 0 ||
            (index > 0 &&
             !items[index - 1].isDivider &&
             items[index - 1].message != null &&
             msg.createdAt.difference(
               items[index - 1].message!.createdAt).inMinutes > 5);

        return MessageBubble(
          message:        msg,
          isMe:           isMe,
          showTimestamp:  showTs,
          index:          index,
        );
      },
    );
  }
}

class _ChatItem {
  const _ChatItem._({this.message, this.date});
  final Message?  message;
  final DateTime? date;

  bool get isDivider => date != null && message == null;

  factory _ChatItem.message(Message m)       => _ChatItem._(message: m);
  factory _ChatItem.dateSeparator(DateTime d)=> _ChatItem._(date: d);
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.date});
  final DateTime date;

  String get _label {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d     = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(_label,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.neutral500)),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// WALI APPROVAL BANNER
// ─────────────────────────────────────────────

class _WaliApprovalBanner extends StatelessWidget {
  const _WaliApprovalBanner({required this.match});
  final Match match;

  @override
  Widget build(BuildContext context) {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color:   AppColors.goldPrimary.withOpacity(0.1),
      child: Row(
        children: [
          const Text('🤲', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Waiting for family blessings before chat opens.',
              style: AppTypography.bodySmall.copyWith(
                color:  AppColors.goldDark,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

// ─────────────────────────────────────────────
// MODERATION ALERT
// ─────────────────────────────────────────────

class _ModerationAlert extends StatelessWidget {
  const _ModerationAlert({required this.message, required this.onDismiss});
  final String       message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color:   AppColors.errorLight,
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.error)),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close_rounded,
                color: AppColors.error, size: 18),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).shakeX(amount: 3);
  }
}

// ─────────────────────────────────────────────
// LOADING / EMPTY
// ─────────────────────────────────────────────

class _ChatLoading extends StatelessWidget {
  const _ChatLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppColors.roseDeep, strokeWidth: 2),
          SizedBox(height: 16),
          Text('Loading messages...'),
        ],
      ),
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🌙', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 20),
          Text(
            'Bismillah — begin with the best',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.neutral700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Start the conversation with a sincere greeting. '
            'Your wali can see all messages.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color:  AppColors.neutral500,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          const ArabicText(
            'السَّلَامُ عَلَيْكُمْ وَرَحْمَةُ اللَّهِ وَبَرَكَاتُهُ',
            style: TextStyle(
              fontFamily: 'Scheherazade',
              fontSize:   18,
              color:      AppColors.goldPrimary,
              height:     2.0,
            ),
          ),
        ],
      ).animate().fadeIn(duration: 600.ms),
    );
  }
}
