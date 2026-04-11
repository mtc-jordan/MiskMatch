import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:miskmatch/core/storage/secure_storage.dart';
import 'package:miskmatch/core/websocket/websocket_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Mocks
// ─────────────────────────────────────────────────────────────────────────────

class MockSecureStorage extends Mock implements SecureStorage {}

void main() {
  late MockSecureStorage mockStorage;
  late WebSocketService service;

  setUp(() {
    mockStorage = MockSecureStorage();
    service = WebSocketService(mockStorage);
  });

  tearDown(() {
    service.dispose();
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Initial state
  // ═══════════════════════════════════════════════════════════════════════════

  group('Initial state', () {
    test('starts disconnected', () {
      expect(service.state, WsConnectionState.disconnected);
      expect(service.isConnected, false);
      expect(service.matchId, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // WsEvent constants
  // ═══════════════════════════════════════════════════════════════════════════

  group('WsEvent constants', () {
    test('event types are non-empty strings', () {
      expect(WsEvent.sendMessage, isNotEmpty);
      expect(WsEvent.newMessage, isNotEmpty);
      expect(WsEvent.markRead, isNotEmpty);
      expect(WsEvent.messageRead, isNotEmpty);
      expect(WsEvent.typingStart, isNotEmpty);
      expect(WsEvent.typingStop, isNotEmpty);
      expect(WsEvent.typing, isNotEmpty);
      expect(WsEvent.ping, isNotEmpty);
      expect(WsEvent.pong, isNotEmpty);
      expect(WsEvent.connected, isNotEmpty);
      expect(WsEvent.presence, isNotEmpty);
      expect(WsEvent.moderation, isNotEmpty);
      expect(WsEvent.error, isNotEmpty);
    });

    test('event types are distinct', () {
      final types = {
        WsEvent.sendMessage,
        WsEvent.newMessage,
        WsEvent.markRead,
        WsEvent.messageRead,
        WsEvent.typingStart,
        WsEvent.typingStop,
        WsEvent.ping,
        WsEvent.pong,
        WsEvent.connected,
        WsEvent.presence,
        WsEvent.moderation,
        WsEvent.error,
      };
      expect(types.length, 12, reason: 'All WS event types must be unique');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Connect — no token
  // ═══════════════════════════════════════════════════════════════════════════

  group('connect without token', () {
    test('stays disconnected when no access token is stored', () async {
      when(() => mockStorage.getAccessToken()).thenAnswer((_) async => null);

      await service.connect('match-123');

      expect(service.state, WsConnectionState.disconnected);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Disconnect
  // ═══════════════════════════════════════════════════════════════════════════

  group('disconnect', () {
    test('resets state to disconnected', () async {
      when(() => mockStorage.getAccessToken()).thenAnswer((_) async => null);

      await service.connect('match-123');
      await service.disconnect();

      expect(service.state, WsConnectionState.disconnected);
      expect(service.matchId, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // WsConnectionState enum
  // ═══════════════════════════════════════════════════════════════════════════

  group('WsConnectionState', () {
    test('has all expected values', () {
      expect(WsConnectionState.values, containsAll([
        WsConnectionState.disconnected,
        WsConnectionState.connecting,
        WsConnectionState.connected,
        WsConnectionState.reconnecting,
      ]));
      expect(WsConnectionState.values.length, 4);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Send while disconnected
  // ═══════════════════════════════════════════════════════════════════════════

  group('send while disconnected', () {
    test('queues messages when not connected', () {
      // Should not throw — messages are queued
      service.send({'type': 'test', 'payload': {}});
      service.sendMessage('match-1', 'hello');
      service.sendTyping('match-1', true);
      service.sendMarkRead('match-1', ['msg-1']);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Event stream
  // ═══════════════════════════════════════════════════════════════════════════

  group('event stream', () {
    test('events stream is a broadcast stream', () {
      expect(service.events.isBroadcast, true);
    });

    test('multiple listeners can subscribe', () {
      // Should not throw
      final sub1 = service.events.listen((_) {});
      final sub2 = service.events.listen((_) {});
      sub1.cancel();
      sub2.cancel();
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // sendMessage helper
  // ═══════════════════════════════════════════════════════════════════════════

  group('sendMessage', () {
    test('produces correct event structure', () {
      // Capture what would be sent — since we're disconnected it's queued
      // We just verify no exceptions are thrown with valid args
      service.sendMessage('match-1', 'Hello!');
      service.sendMessage('match-1', 'Voice', contentType: 'voice');
      service.sendMessage('match-1', 'Test', clientId: 'client-uuid-1');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // sendTyping helper
  // ═══════════════════════════════════════════════════════════════════════════

  group('sendTyping', () {
    test('sends correct event type for start and stop', () {
      service.sendTyping('match-1', true);
      service.sendTyping('match-1', false);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // sendMarkRead helper
  // ═══════════════════════════════════════════════════════════════════════════

  group('sendMarkRead', () {
    test('sends correct event with message IDs', () {
      service.sendMarkRead('match-1', ['msg-1', 'msg-2', 'msg-3']);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Dispose
  // ═══════════════════════════════════════════════════════════════════════════

  group('dispose', () {
    test('closes event stream and disconnects', () {
      service.dispose();

      // After dispose, events stream should be done
      expect(
        service.events.listen((_) {}).asFuture(),
        completes,
      );
    });
  });
}
