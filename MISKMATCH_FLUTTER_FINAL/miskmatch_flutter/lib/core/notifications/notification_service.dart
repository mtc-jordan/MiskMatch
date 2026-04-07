import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../router/app_router.dart';

/// MiskMatch — Push Notification Service
///
/// Handles incoming FCM notifications with deep-link routing.
///
/// Notification types from backend:
///   new_interest     → /matches (new interest received)
///   wali_decision    → /match/:id (wali approved/declined)
///   new_message      → /match/:id/chat
///   game_your_turn   → /match/:id/games/:type
///   time_capsule_open→ /match/:id/games/time_capsule
///   match_mutual     → /matches (both sides interested)
///
/// Integration:
///   Call NotificationService.init(router) from main.dart after
///   Firebase.initializeApp() and runApp.

/// Top-level handler for background/terminated FCM messages.
/// Must be a top-level function (not a class method).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('NotificationService: background message ${message.messageId}');
}

class NotificationPayload {
  const NotificationPayload({
    required this.type,
    this.matchId,
    this.gameType,
    this.senderName,
    this.body,
  });

  final String  type;
  final String? matchId;
  final String? gameType;
  final String? senderName;
  final String? body;

  factory NotificationPayload.fromData(Map<String, dynamic> data) =>
      NotificationPayload(
        type:       data['type']        as String? ?? '',
        matchId:    data['match_id']    as String?,
        gameType:   data['game_type']   as String?,
        senderName: data['sender_name'] as String?,
        body:       data['body']        as String?,
      );

  /// Resolve the deep-link route from this notification
  String? get route {
    return switch (type) {
      'new_interest'      => AppRoutes.matches,
      'match_mutual'      => AppRoutes.matches,
      'new_message'       =>
          matchId != null ? AppRoutes.chatPath(matchId!) : AppRoutes.matches,
      'wali_decision'     =>
          matchId != null ? AppRoutes.matchPath(matchId!) : AppRoutes.matches,
      'game_your_turn'    =>
          matchId != null && gameType != null
              ? AppRoutes.gamePlayPath(matchId!, gameType!)
              : AppRoutes.matches,
      'time_capsule_open' =>
          matchId != null
              ? AppRoutes.gamePlayPath(matchId!, 'time_capsule')
              : AppRoutes.matches,
      'wali_pending'      => AppRoutes.wali,
      'wali_flagged'      => AppRoutes.wali,
      _                   => null,
    };
  }
}

class NotificationService {
  NotificationService._();

  static GoRouter? _router;

  /// Call once after runApp — pass the GoRouter instance
  static Future<void> init(GoRouter router) async {
    _router = router;
    await _setupFcm();
  }

  /// Route to the correct screen from a notification payload
  static void handlePayload(Map<String, dynamic> data) {
    if (_router == null) return;
    final payload = NotificationPayload.fromData(data);
    final route   = payload.route;
    if (route != null) {
      debugPrint('NotificationService: routing to $route');
      _router!.push(route);
    }
  }

  // ── FCM INTEGRATION ───────────────────────────────────────────────────────

  static Future<void> _setupFcm() async {
    final messaging = FirebaseMessaging.instance;

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission (iOS + Android 13+)
    await messaging.requestPermission(
      alert: true, badge: true, sound: true,
    );

    // Get FCM token and register with backend
    final token = await messaging.getToken();
    if (token != null) {
      debugPrint('NotificationService: FCM token obtained');
      await _registerToken(token);
    }
    messaging.onTokenRefresh.listen(_registerToken);

    // Foreground messages
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('NotificationService: foreground message ${message.messageId}');
      final data = message.data;
      if (data.isNotEmpty) handlePayload(data);
    });

    // Background tap — user tapped notification while app was in background
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('NotificationService: opened from background');
      handlePayload(message.data);
    });

    // Cold start tap — app was terminated, user tapped notification
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      debugPrint('NotificationService: opened from terminated state');
      handlePayload(initial.data);
    }
  }

  static Future<void> _registerToken(String token) async {
    debugPrint('NotificationService: registering device token');
    // TODO: POST token to /api/v1/auth/device-token
    // final dio = ... get Dio instance
    // await dio.post('/auth/device-token', data: {'token': token, 'platform': Platform.isIOS ? 'ios' : 'android'});
  }
}

// ── Notification display helper ───────────────────────────────────────────────

abstract class NotificationDisplay {
  /// Human-readable title for each notification type
  static String title(String type) => switch (type) {
    'new_interest'      => 'New interest received 🌹',
    'match_mutual'      => 'Mutual interest! 🌙',
    'new_message'       => 'New message',
    'wali_decision'     => 'Guardian decision',
    'game_your_turn'    => 'Your turn in a game 🎮',
    'time_capsule_open' => 'Time Capsule opened! 🕰️',
    'wali_pending'      => 'Decision needed 🛡️',
    'wali_flagged'      => 'Message flagged ⚠️',
    _                   => 'MiskMatch',
  };

  static String icon(String type) => switch (type) {
    'new_interest'      => '🌹',
    'match_mutual'      => '🌙',
    'new_message'       => '💬',
    'wali_decision'     => '🛡️',
    'game_your_turn'    => '🎮',
    'time_capsule_open' => '🕰️',
    'wali_pending'      => '🤲',
    'wali_flagged'      => '⚠️',
    _                   => '🌟',
  };
}

// ── Provider ──────────────────────────────────────────────────────────────────

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService._();
});
