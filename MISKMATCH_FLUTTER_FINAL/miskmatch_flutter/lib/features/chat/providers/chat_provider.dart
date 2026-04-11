import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miskmatch/core/websocket/websocket_service.dart';
import 'package:miskmatch/features/match/data/match_models.dart';
import '../data/chat_repository.dart';
import 'package:miskmatch/features/auth/providers/auth_provider.dart';
import 'package:miskmatch/shared/models/api_response.dart';

// ─────────────────────────────────────────────
// CHAT STATE
// ─────────────────────────────────────────────

class ChatState {
  const ChatState({
    this.messages      = const [],
    this.isLoading     = false,
    this.isSending     = false,
    this.hasMore       = true,
    this.error,
    this.moderationAlert,
    this.typingUsers   = const {},
    this.onlineUsers   = const {},
  });

  final List<Message> messages;
  final bool          isLoading;
  final bool          isSending;
  final bool          hasMore;
  final AppError?     error;
  final String?       moderationAlert; // AI blocked message notice
  final Set<String>   typingUsers;     // userIds currently typing
  final Set<String>   onlineUsers;

  bool get anyoneTyping    => typingUsers.isNotEmpty;
  List<MessageGroup> get grouped => groupMessagesByDate(messages);

  ChatState copyWith({
    List<Message>? messages, bool? isLoading, bool? isSending,
    bool? hasMore, AppError? error, String? moderationAlert,
    Set<String>? typingUsers, Set<String>? onlineUsers,
    bool clearModAlert = false,
    bool clearError    = false,
  }) => ChatState(
    messages:       messages        ?? this.messages,
    isLoading:      isLoading       ?? this.isLoading,
    isSending:      isSending       ?? this.isSending,
    hasMore:        hasMore         ?? this.hasMore,
    error:          clearError      ? null : (error     ?? this.error),
    moderationAlert:clearModAlert   ? null : (moderationAlert ?? this.moderationAlert),
    typingUsers:    typingUsers     ?? this.typingUsers,
    onlineUsers:    onlineUsers     ?? this.onlineUsers,
  );
}

// ─────────────────────────────────────────────
// CHAT NOTIFIER
// ─────────────────────────────────────────────

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier({
    required this.matchId,
    required this.myUserId,
    required ChatRepository chatRepo,
    required WebSocketService ws,
  })  : _chatRepo = chatRepo,
        _ws       = ws,
        super(const ChatState()) {
    _initWs();
    loadMessages();
  }

  final String          matchId;
  final String          myUserId;
  final ChatRepository  _chatRepo;
  final WebSocketService _ws;

  StreamSubscription?  _wsSub;
  Timer?               _typingDebounce;
  bool                 _isTyping = false;

  // ── WebSocket event handler ───────────────────────────────────────────────
  void _initWs() {
    _ws.connect(matchId);
    _wsSub = _ws.events.listen(_handleWsEvent);
  }

  void _handleWsEvent(Map<String, dynamic> event) {
    final type    = event['type']    as String?;
    final payload = event['payload'] as Map<String, dynamic>? ?? {};

    switch (type) {
      case WsEvent.newMessage:
        final msg = Message.fromJson(payload);
        if (msg.matchId == matchId) {
          _addMessage(msg);
          // Auto-mark as read if it's from the other person
          if (msg.senderId != myUserId) {
            _ws.sendMarkRead(matchId, [msg.id]);
          }
        }

      case WsEvent.messageRead:
        final ids = (payload['message_ids'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toSet() ?? {};
        state = state.copyWith(
          messages: state.messages.map((m) {
            if (ids.contains(m.id) && m.senderId == myUserId) {
              return Message(
                id: m.id, matchId: m.matchId, senderId: m.senderId,
                content: m.content, contentType: m.contentType,
                mediaUrl: m.mediaUrl, status: MessageStatus.read,
                createdAt: m.createdAt, senderName: m.senderName,
              );
            }
            return m;
          }).toList(),
        );

      case WsEvent.typing:
        final userId   = payload['user_id']   as String?;
        final isTyping = payload['typing']    as bool? ?? false;
        if (userId != null && userId != myUserId) {
          final newTyping = Set<String>.from(state.typingUsers);
          if (isTyping) {
            newTyping.add(userId);
          } else {
            newTyping.remove(userId);
          }
          state = state.copyWith(typingUsers: newTyping);
        }

      case WsEvent.presence:
        final userId = payload['user_id'] as String?;
        final online = payload['online']  as bool? ?? false;
        if (userId != null) {
          final newOnline = Set<String>.from(state.onlineUsers);
          if (online) newOnline.add(userId); else newOnline.remove(userId);
          state = state.copyWith(onlineUsers: newOnline);
        }

      case WsEvent.moderation:
        state = state.copyWith(
          moderationAlert: payload['message'] as String? ??
              'Message not delivered — please keep within Islamic guidelines.',
        );
        // Auto-clear after 4 seconds
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) state = state.copyWith(clearModAlert: true);
        });

      case WsEvent.connected:
        final online = (payload['online_users'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toSet() ?? {};
        state = state.copyWith(onlineUsers: online);
    }
  }

  void _addMessage(Message msg) {
    // Avoid duplicates
    if (state.messages.any((m) => m.id == msg.id)) return;
    state = state.copyWith(
      messages: [...state.messages, msg],
    );
  }

  // ── Load messages (initial + pagination) ──────────────────────────────────
  Future<void> loadMessages({bool refresh = false}) async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _chatRepo.getMessages(
      matchId,
      beforeId: refresh ? null : state.messages.firstOrNull?.id,
    );

    state = switch (result) {
      ApiSuccess(data: final msgs) => state.copyWith(
          messages:  refresh
              ? msgs
              : [...msgs, ...state.messages],
          isLoading: false,
          hasMore:   msgs.length >= 50,
        ),
      ApiError(error: final e) => state.copyWith(
          isLoading: false,
          error:     e,
        ),
    };
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading || state.messages.isEmpty) return;
    await loadMessages();
  }

  // ── Send text message ─────────────────────────────────────────────────────
  Future<void> sendText(String content) async {
    if (content.trim().isEmpty) return;

    state = state.copyWith(isSending: true);
    _stopTyping();

    // Try WebSocket first (fast path)
    if (_ws.isConnected) {
      _ws.sendMessage(matchId, content.trim());
      state = state.copyWith(isSending: false);
      return;
    }

    // REST fallback
    final result = await _chatRepo.sendMessage(
        matchId: matchId, content: content.trim());
    state = switch (result) {
      ApiSuccess(data: final msg) => () {
          _addMessage(msg);
          return state.copyWith(isSending: false);
        }(),
      ApiError(error: final e) => state.copyWith(
          isSending: false, error: e),
    };
  }

  // ── Send voice message ────────────────────────────────────────────────────
  Future<void> sendVoice(String localPath) async {
    state = state.copyWith(isSending: true);

    final file = File(localPath);
    final uploadResult = await _chatRepo.uploadAudio(matchId, file);

    switch (uploadResult) {
      case ApiSuccess(data: final mediaUrl):
        final sendResult = await _chatRepo.sendMessage(
          matchId:     matchId,
          content:     '',
          contentType: 'audio',
          mediaUrl:    mediaUrl,
        );
        state = switch (sendResult) {
          ApiSuccess(data: final msg) => () {
              _addMessage(msg);
              return state.copyWith(isSending: false);
            }(),
          ApiError(error: final e) => state.copyWith(
              isSending: false, error: e),
        };

      case ApiError(error: final e):
        debugPrint('Voice upload failed: $e');
        state = state.copyWith(isSending: false, error: e);
    }
  }

  // ── Typing indicators ──────────────────────────────────────────────────────
  void onTextChanged(String text) {
    if (text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      _ws.sendTyping(matchId, true);
    }
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 1500), _stopTyping);
  }

  void _stopTyping() {
    if (_isTyping) {
      _isTyping = false;
      _ws.sendTyping(matchId, false);
    }
    _typingDebounce?.cancel();
  }

  // ── Mark read ─────────────────────────────────────────────────────────────
  void markVisibleRead(List<String> messageIds) {
    if (messageIds.isEmpty) return;
    _ws.sendMarkRead(matchId, messageIds);
    _chatRepo.markRead(matchId, messageIds);
  }

  // ── Clear moderation alert ────────────────────────────────────────────────
  void clearModerationAlert() =>
      state = state.copyWith(clearModAlert: true);

  @override
  void dispose() {
    _wsSub?.cancel();
    _typingDebounce?.cancel();
    _stopTyping();
    super.dispose();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final chatProvider = StateNotifierProvider.family
    .autoDispose<ChatNotifier, ChatState, String>((ref, matchId) {
  final authState = ref.read(authProvider);
  final myUserId  = authState is AuthAuthenticated ? authState.userId : '';

  return ChatNotifier(
    matchId:  matchId,
    myUserId: myUserId,
    chatRepo: ref.watch(chatRepositoryProvider),
    ws:       ref.watch(webSocketServiceProvider),
  );
});
