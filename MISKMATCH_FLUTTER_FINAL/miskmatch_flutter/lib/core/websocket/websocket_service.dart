import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:miskmatch/core/config/env.dart';
import 'package:miskmatch/core/storage/secure_storage.dart';
import 'package:miskmatch/features/match/data/match_models.dart';

// ─────────────────────────────────────────────
// WS EVENT TYPES  (mirrors backend constants)
// ─────────────────────────────────────────────

abstract class WsEvent {
  static const sendMessage  = 'send_message';
  static const newMessage   = 'new_message';
  static const markRead     = 'mark_read';
  static const messageRead  = 'message_read';
  static const typingStart  = 'typing_start';
  static const typingStop   = 'typing_stop';
  static const typing       = 'typing';
  static const ping         = 'ping';
  static const pong         = 'pong';
  static const connected    = 'connected';
  static const presence     = 'presence';
  static const moderation   = 'moderation_alert';
  static const error        = 'error';
}

// ─────────────────────────────────────────────
// CONNECTION STATE
// ─────────────────────────────────────────────

enum WsConnectionState { disconnected, connecting, connected, reconnecting }

// ─────────────────────────────────────────────
// WEBSOCKET SERVICE
// ─────────────────────────────────────────────

/// Manages a single WebSocket connection per match.
/// Features:
///   - Auto-reconnect with exponential backoff (max 30s)
///   - Ping/pong keepalive every 25 seconds
///   - Event stream for message/typing/read events
///   - Queues messages while reconnecting

class WebSocketService {
  WebSocketService(this._storage);

  final SecureStorage _storage;

  WebSocketChannel?       _channel;
  StreamSubscription?     _sub;
  Timer?                  _pingTimer;
  Timer?                  _reconnectTimer;
  Timer?                  _tokenRefreshTimer;

  String?                 _currentMatchId;
  WsConnectionState       _state = WsConnectionState.disconnected;
  int                     _reconnectAttempts = 0;
  static const _maxReconnectDelay = 30; // seconds
  static const _maxReconnectAttempts = 15; // give up after 15 attempts
  static const _pingInterval      = 25; // seconds

  // Pending messages to send after reconnect
  final _pendingQueue = <Map<String, dynamic>>[];

  // Event stream — chat screen subscribes to this
  final _eventController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get events => _eventController.stream;

  WsConnectionState get state => _state;
  bool get isConnected => _state == WsConnectionState.connected;
  String? get matchId  => _currentMatchId;

  // ── Connect ───────────────────────────────────────────────────────────────
  Future<void> connect(String matchId) async {
    if (_currentMatchId == matchId && isConnected) return;

    _currentMatchId = matchId;
    await _doConnect();
  }

  Future<void> _doConnect() async {
    if (_currentMatchId == null) return;

    _setState(WsConnectionState.connecting);
    _cleanupChannel();

    final token = await _storage.getAccessToken();
    if (token == null) {
      _setState(WsConnectionState.disconnected);
      return;
    }

    // Connect without token in URL — authenticate via first message
    final wsUrl = '${AppConfig.wsBaseUrl}'
        '/messages/ws/$_currentMatchId';

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // Wait for connection to establish
      await _channel!.ready.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('WS connect timeout'),
      );

      // Send auth as first message (token never appears in URL/logs)
      _channel!.sink.add(jsonEncode({
        'type': 'authenticate',
        'payload': {'token': token},
      }));

      _setState(WsConnectionState.connected);
      _reconnectAttempts = 0;
      _startPing();
      _startTokenRefreshTimer();
      _flushPendingQueue();

      _sub = _channel!.stream.listen(
        _onData,
        onError: _onError,
        onDone:  _onDone,
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('WS connect error: $e');
      _scheduleReconnect();
    }
  }

  // ── Data handler ──────────────────────────────────────────────────────────
  void _onData(dynamic raw) {
    try {
      final event = jsonDecode(raw as String) as Map<String, dynamic>;
      final type  = event['type'] as String?;

      if (type == WsEvent.pong) return; // keepalive ack

      _eventController.add(event);
    } catch (e) {
      debugPrint('WS parse error: $e');
    }
  }

  void _onError(Object error) {
    debugPrint('WS error: $error');
    _scheduleReconnect();
  }

  void _onDone() {
    debugPrint('WS closed');
    if (_state != WsConnectionState.disconnected) {
      _scheduleReconnect();
    }
  }

  // ── Send ──────────────────────────────────────────────────────────────────
  void send(Map<String, dynamic> event) {
    if (isConnected && _channel != null) {
      try {
        _channel!.sink.add(jsonEncode(event));
      } catch (e) {
        _pendingQueue.add(event);
      }
    } else {
      _pendingQueue.add(event);
    }
  }

  void sendMessage(String matchId, String content,
      {String contentType = 'text', String? clientId}) {
    send({
      'type': WsEvent.sendMessage,
      'payload': {
        'match_id':     matchId,
        'content':      content,
        'content_type': contentType,
        if (clientId != null) 'client_id': clientId,
      },
    });
  }

  void sendTyping(String matchId, bool isTyping) {
    send({
      'type':    isTyping ? WsEvent.typingStart : WsEvent.typingStop,
      'payload': {'match_id': matchId},
    });
  }

  void sendMarkRead(String matchId, List<String> messageIds) {
    send({
      'type':    WsEvent.markRead,
      'payload': {'match_id': matchId, 'message_ids': messageIds},
    });
  }

  // ── Reconnect ─────────────────────────────────────────────────────────────
  void _scheduleReconnect() {
    if (_state == WsConnectionState.disconnected) return;

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('WS max reconnect attempts reached — giving up');
      _setState(WsConnectionState.disconnected);
      _cleanupChannel();
      return;
    }

    _setState(WsConnectionState.reconnecting);
    _cleanupChannel();

    final delay = min(
      _maxReconnectDelay,
      (1 << _reconnectAttempts).clamp(1, _maxReconnectDelay),
    );
    _reconnectAttempts++;

    debugPrint('WS reconnect in ${delay}s (attempt $_reconnectAttempts/$_maxReconnectAttempts)');

    _reconnectTimer = Timer(Duration(seconds: delay), _doConnect);
  }

  // ── Ping keepalive ────────────────────────────────────────────────────────
  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(
      const Duration(seconds: _pingInterval),
      (_) => send({'type': WsEvent.ping, 'payload': {}}),
    );
  }

  // ── Token refresh — reconnect before JWT expires ─────────────────────────
  static const _tokenRefreshMinutes = 25; // JWT typically expires in 30 min

  void _startTokenRefreshTimer() {
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = Timer(
      const Duration(minutes: _tokenRefreshMinutes),
      () async {
        debugPrint('WS token refresh: reconnecting with fresh token');
        // Disconnect and reconnect — the reconnect will fetch the latest
        // access token from storage (already refreshed by RefreshInterceptor
        // during normal API calls).
        final matchId = _currentMatchId;
        if (matchId != null && _state != WsConnectionState.disconnected) {
          _cleanupChannel();
          await _doConnect();
        }
      },
    );
  }

  // ── Queue flush after reconnect ───────────────────────────────────────────
  void _flushPendingQueue() {
    if (_pendingQueue.isEmpty) return;
    final toSend = List<Map<String, dynamic>>.from(_pendingQueue);
    _pendingQueue.clear();
    for (final event in toSend) {
      send(event);
    }
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────
  void _cleanupChannel() {
    _pingTimer?.cancel();
    _tokenRefreshTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
    _sub     = null;
  }

  void _setState(WsConnectionState s) => _state = s;

  Future<void> disconnect() async {
    _setState(WsConnectionState.disconnected);
    _reconnectTimer?.cancel();
    _cleanupChannel();
    _currentMatchId = null;
    _reconnectAttempts = 0;
  }

  void dispose() {
    _eventController.close();
    disconnect();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService(ref.watch(secureStorageProvider));
  ref.onDispose(service.dispose);
  return service;
});

// ── Connection state stream ───────────────────────────────────────────────────

final wsConnectionStateProvider =
    StreamProvider.family<WsConnectionState, String>((ref, matchId) async* {
  final service = ref.watch(webSocketServiceProvider);
  await service.connect(matchId);
  // Poll connection state — in production use a ChangeNotifier
  while (true) {
    await Future.delayed(const Duration(seconds: 1));
    yield service.state;
  }
});
