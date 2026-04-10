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
  int   _newBelow   = 0;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scrollCtrl.position;
    final wasAtBottom = _atBottom;
    setState(() {
      _atBottom = pos.pixels >= pos.maxScrollExtent - 120;
      if (_atBottom) _newBelow = 0;
    });
    if (pos.pixels <= 100) {
      ref.read(chatProvider(widget.matchId).notifier).loadMore();
    }
  }

  void _scrollToBottom({bool animate = false}) {
    if (!_scrollCtrl.hasClients) return;
    if (animate) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: 300.ms, curve: Curves.easeOut,
      );
    } else {
      _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
    }
    setState(() => _newBelow = 0);
  }

  String get _myUserId {
    final auth = ref.read(authProvider);
    return auth is AuthAuthenticated ? auth.userId : '';
  }

  @override
  Widget build(BuildContext context) {
    final chat  = ref.watch(chatProvider(widget.matchId));
    final match = ref.watch(matchDetailProvider(widget.matchId));

    // Auto-scroll on new messages
    ref.listen(chatProvider(widget.matchId), (prev, next) {
      if (prev != null && next.messages.length > prev.messages.length) {
        if (_atBottom) {
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => _scrollToBottom(animate: true));
        } else {
          setState(() => _newBelow += next.messages.length - prev.messages.length);
        }
      }
    });

    final otherProfile = match.valueOrNull?.otherProfile(_myUserId);
    final otherName    = otherProfile?.displayFirstName ?? 'Match';
    final isActive     = match.valueOrNull?.status.canChat ?? false;

    return Scaffold(
      backgroundColor: context.scaffoldColor,
      appBar: _buildAppBar(context, otherName, otherProfile, chat),
      body: Column(
        children: [
          // ── Wali approval banner ──────────────────────────────
          if (match.hasValue && match.value!.status.needsWali)
            _WaliApprovalBanner(),

          // ── Moderation alert ──────────────────────────────────
          if (chat.moderationAlert != null)
            _ModerationAlert(
              message:   chat.moderationAlert!,
              onDismiss: () => ref
                  .read(chatProvider(widget.matchId).notifier)
                  .clearModerationAlert(),
            ),

          // ── Message list ──────────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                chat.isLoading && chat.messages.isEmpty
                    ? const _ChatLoading()
                    : _MessageList(
                        groups:     chat.grouped,
                        myUserId:   _myUserId,
                        scrollCtrl: _scrollCtrl,
                        matchId:    widget.matchId,
                      ),

                // ── Scroll-to-bottom FAB ────────────────────────
                if (!_atBottom)
                  Positioned(
                    right: 16, bottom: 12,
                    child: GestureDetector(
                      onTap: () => _scrollToBottom(animate: true),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.roseDeep,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.roseDeep.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: AppColors.white, size: 24),
                          ),
                          // New message badge
                          if (_newBelow > 0)
                            Positioned(
                              top: -4, right: -4,
                              child: Container(
                                width: 20, height: 20,
                                decoration: const BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text('$_newBelow',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                        .animate()
                        .scale(begin: const Offset(0.6, 0.6),
                               end: const Offset(1.0, 1.0),
                               duration: 200.ms,
                               curve: Curves.easeOutBack)
                        .fadeIn(duration: 200.ms),
                  ),
              ],
            ),
          ),

          // ── Typing indicator ──────────────────────────────────
          if (chat.anyoneTyping)
            TypingIndicator(userName: otherName),

          // ── Input bar ─────────────────────────────────────────
          SafeArea(
            top: false,
            child: ChatInputBar(
              disabled:    !isActive,
              onSendText:  (text) => ref
                  .read(chatProvider(widget.matchId).notifier)
                  .sendText(text),
              onSendVoice: (path) => ref
                  .read(chatProvider(widget.matchId).notifier)
                  .sendVoice(path),
              onTyping:    (text) => ref
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
  ) {
    final isOnline = chat.onlineUsers.isNotEmpty;

    return AppBar(
      backgroundColor:       context.scaffoldColor,
      elevation:             0,
      scrolledUnderElevation: 1,
      surfaceTintColor:      Colors.transparent,
      leading: const BackButton(),
      titleSpacing: 0,
      title: Row(
        children: [
          // Avatar 40px with online dot
          Stack(
            children: [
              Container(
                width: 40, height: 40,
                decoration: const BoxDecoration(
                  gradient: AppColors.roseGradient,
                  shape:    BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    otherName.isNotEmpty
                        ? otherName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize:   18,
                      color:      AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              // Green online dot 8px
              if (isOnline)
                Positioned(
                  right: 0, bottom: 0,
                  child: Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color:  AppColors.success,
                      shape:  BoxShape.circle,
                      border: Border.all(
                        color: context.scaffoldColor, width: 2),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(width: 10),

          // Name + status
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(otherName,
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color:      context.onSurface,
                ),
              ),
              Text(
                isOnline ? 'Online' : 'Last seen recently',
                style: AppTypography.labelSmall.copyWith(
                  color:    isOnline
                      ? AppColors.success
                      : context.mutedText,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        // Video call button
        IconButton(
          icon: const Icon(Icons.videocam_outlined, size: 22),
          color: context.mutedText,
          tooltip: 'Chaperoned call',
          onPressed: () {},
        ),
        // More menu
        IconButton(
          icon: const Icon(Icons.more_vert_rounded, size: 22),
          color: context.mutedText,
          onPressed: () {},
        ),
        const SizedBox(width: 4),
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
    if (groups.isEmpty) return const _EmptyChatState();

    final items = <_ChatItem>[];
    for (final group in groups) {
      items.add(_ChatItem.dateSeparator(group.date));
      for (var i = 0; i < group.messages.length; i++) {
        items.add(_ChatItem.message(group.messages[i]));
      }
    }

    return ListView.builder(
      controller: scrollCtrl,
      padding:    const EdgeInsets.only(top: 8, bottom: 8),
      itemCount:  items.length,
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
        final showTs = index == 0 ||
            (index > 0 &&
             !items[index - 1].isDivider &&
             items[index - 1].message != null &&
             msg.createdAt.difference(
               items[index - 1].message!.createdAt).inMinutes > 5);

        return MessageBubble(
          message:       msg,
          isMe:          isMe,
          showTimestamp: showTs,
          index:         index,
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

  factory _ChatItem.message(Message m)        => _ChatItem._(message: m);
  factory _ChatItem.dateSeparator(DateTime d) => _ChatItem._(date: d);
}

// ─────────────────────────────────────────────
// DATE DIVIDER — horizontal rule + centred chip
// ─────────────────────────────────────────────

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
        Expanded(
          child: Container(height: 1,
              color: context.subtleBg),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color:        context.subtleBg,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(_label,
              style: AppTypography.labelSmall.copyWith(
                color:    context.mutedText,
                fontSize: 11,
              ),
            ),
          ),
        ),
        Expanded(
          child: Container(height: 1,
              color: context.subtleBg),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// WALI APPROVAL BANNER — gold strip, slideY
// ─────────────────────────────────────────────

class _WaliApprovalBanner extends StatelessWidget {
  const _WaliApprovalBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppColors.goldPrimary.withOpacity(0.12),
          AppColors.goldLight.withOpacity(0.08),
        ]),
      ),
      child: Row(
        children: [
          const Text('🤲', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Waiting for family blessings',
              style: AppTypography.bodySmall.copyWith(
                color:      AppColors.goldDark,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .slideY(begin: -1.0, end: 0, duration: 400.ms,
                curve: Curves.easeOutCubic)
        .fadeIn(duration: 300.ms);
  }
}

// ─────────────────────────────────────────────
// MODERATION ALERT — red strip, shakeX
// ─────────────────────────────────────────────

class _ModerationAlert extends StatelessWidget {
  const _ModerationAlert({
    required this.message,
    required this.onDismiss,
  });
  final String       message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color:   context.errorLightBg,
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.error),
            ),
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
      child: CircularProgressIndicator(
          color: AppColors.roseDeep, strokeWidth: 2),
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
            style: TextStyle(
              fontFamily:  'Georgia',
              fontSize:    20,
              fontWeight:  FontWeight.w700,
              color:       context.subtleText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Start the conversation with a sincere greeting. '
            'Your wali can see all messages.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color:  context.mutedText,
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
