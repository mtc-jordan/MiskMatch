import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:miskmatch/features/auth/providers/auth_provider.dart';
import 'package:miskmatch/features/auth/screens/splash_screen.dart';
import 'package:miskmatch/features/auth/screens/phone_screen.dart';
import 'package:miskmatch/features/auth/screens/otp_screen.dart';
import 'package:miskmatch/features/auth/screens/niyyah_screen.dart';
import 'package:miskmatch/features/auth/screens/wali_setup_screen.dart';
import 'package:miskmatch/features/discovery/screens/discovery_screen.dart';
import 'package:miskmatch/features/match/screens/matches_list_screen.dart';
import 'package:miskmatch/features/match/screens/match_screen.dart';
import 'package:miskmatch/features/calls/data/call_models.dart';
import 'package:miskmatch/features/calls/screens/in_call_screen.dart';
import 'package:miskmatch/features/calls/screens/ringing_screen.dart';
import 'package:miskmatch/features/chat/screens/chat_screen.dart';
import 'package:miskmatch/features/games/screens/game_hub_screen.dart';
import 'package:miskmatch/features/games/screens/game_play_screen.dart';
import 'package:miskmatch/features/wali/screens/wali_dashboard_screen.dart';
import 'package:miskmatch/features/profile/screens/profile_screen.dart';
import 'package:miskmatch/features/profile/screens/profile_edit_screen.dart';
import 'package:miskmatch/features/profile/screens/sifr_screen.dart';
import 'package:miskmatch/features/settings/screens/settings_screen.dart';
import 'package:miskmatch/shared/widgets/main_shell.dart';

abstract class AppRoutes {
  static const splash      = '/';
  static const phone       = '/auth/phone';
  static const otp         = '/auth/otp';
  static const niyyah      = '/auth/niyyah';
  static const waliSetup   = '/auth/wali-setup';
  static const discovery   = '/discovery';
  static const matches     = '/matches';
  static const match       = '/match/:matchId';
  static const chat        = '/match/:matchId/chat';
  static const gameHub     = '/match/:matchId/games';
  static const gamePlay    = '/match/:matchId/games/:gameType';
  static const callActive   = '/call/active/:matchId';
  static const callRinging  = '/call/ringing/:callId';
  static const wali        = '/wali';
  static const profile     = '/profile';
  static const profileEdit = '/profile/edit';
  static const profileSifr = '/profile/sifr';
  static const settings    = '/settings';

  static String matchPath(String id)   => '/match/$id';
  static String chatPath(String id)    => '/match/$id/chat';
  static String gameHubPath(String id) => '/match/$id/games';
  static String gamePlayPath(String matchId, String type) => '/match/$matchId/games/$type';
  static String callActivePath(String matchId)  => '/call/active/$matchId';
  static String callRingingPath(String callId)  => '/call/ringing/$callId';
}

/// Notifier that GoRouter listens to for redirect re-evaluation.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(this._ref) {
    _ref.listen(authProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;
}

// ─────────────────────────────────────────────
// ROUTE TRANSITIONS
// ─────────────────────────────────────────────

/// Slide right — for drilldown navigation (match detail, settings, games)
CustomTransitionPage<void> _slideRight(Widget child, GoRouterState state) {
  return CustomTransitionPage(
    key:   state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curve = CurvedAnimation(
        parent: animation,
        curve:  Curves.easeOutCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end:   Offset.zero,
        ).animate(curve),
        child: child,
      );
    },
  );
}

/// Slide up — for chat and in-call screens
CustomTransitionPage<void> _slideUp(Widget child, GoRouterState state) {
  return CustomTransitionPage(
    key:   state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curve = CurvedAnimation(
        parent: animation,
        curve:  Curves.easeOutCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.0, 1.0),
          end:   Offset.zero,
        ).animate(curve),
        child: child,
      );
    },
  );
}

/// Fade + scale — for overlays and special screens
CustomTransitionPage<void> _fadeScale(Widget child, GoRouterState state) {
  return CustomTransitionPage(
    key:   state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curve = CurvedAnimation(
        parent: animation,
        curve:  Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curve,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1.0).animate(curve),
          child: child,
        ),
      );
    },
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthChangeNotifier(ref);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final loc  = state.matchedLocation;
      final auth = ref.read(authProvider);
      final isAuthRoute = loc.startsWith('/auth');
      final isSplash    = loc == AppRoutes.splash;

      if (auth is AuthInitial)          return isSplash ? null : AppRoutes.splash;
      if (auth is AuthUnauthenticated)  return isAuthRoute ? null : AppRoutes.phone;
      if (auth is AuthError)            return isAuthRoute ? null : AppRoutes.phone;
      if (auth is AuthOtpSent)          return loc == AppRoutes.otp ? null : AppRoutes.otp;
      if (auth is AuthAuthenticated) {
        if (auth.needsOnboarding) {
          if (loc == AppRoutes.niyyah || loc == AppRoutes.waliSetup) return null;
          return AppRoutes.niyyah;
        }
        if (isAuthRoute || isSplash) return AppRoutes.discovery;
        return null;
      }
      return null;
    },
    routes: [
      // ── Splash — fade scale ─────────────────────
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (_, state) =>
            _fadeScale(const SplashScreen(), state),
      ),

      // ── Auth flow — slide right ─────────────────
      GoRoute(
        path: AppRoutes.phone,
        pageBuilder: (_, state) =>
            _slideRight(const PhoneScreen(), state),
      ),
      GoRoute(
        path: AppRoutes.otp,
        pageBuilder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return _slideRight(
            OtpScreen(
              phone:     extra?['phone']     as String? ?? '',
              isNewUser: extra?['isNewUser'] as bool?   ?? true,
            ),
            state,
          );
        },
      ),

      // ── Niyyah & Wali setup — fade scale (spiritual) ──
      GoRoute(
        path: AppRoutes.niyyah,
        pageBuilder: (_, state) =>
            _fadeScale(const NiyyahScreen(), state),
      ),
      GoRoute(
        path: AppRoutes.waliSetup,
        pageBuilder: (_, state) =>
            _slideRight(const WaliSetupScreen(), state),
      ),

      // ── Main shell with bottom nav ──────────────
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.discovery,
            pageBuilder: (_, state) =>
                _fadeScale(const DiscoveryScreen(), state),
          ),
          GoRoute(
            path: AppRoutes.matches,
            pageBuilder: (_, state) =>
                _fadeScale(const MatchesListScreen(), state),
          ),
          GoRoute(
            path: AppRoutes.wali,
            pageBuilder: (_, state) =>
                _fadeScale(const WaliDashboardScreen(), state),
          ),
          GoRoute(
            path: AppRoutes.profile,
            pageBuilder: (_, state) =>
                _fadeScale(const ProfileScreen(), state),
            routes: [
              GoRoute(
                path: 'edit',
                pageBuilder: (_, state) =>
                    _slideRight(const ProfileEditScreen(), state),
              ),
              GoRoute(
                path: 'sifr',
                pageBuilder: (_, state) =>
                    _slideRight(const SifrScreen(), state),
              ),
            ],
          ),
        ],
      ),

      // ── Settings — slide right ──────────────────
      GoRoute(
        path: AppRoutes.settings,
        pageBuilder: (_, state) =>
            _slideRight(const SettingsScreen(), state),
      ),

      // ── Calls — slide up (takeover) ─────────────
      // InCallScreen: `extra` must be a Map<String, dynamic> with keys
      //   callType, myName, otherName
      GoRoute(
        path: AppRoutes.callActive,
        pageBuilder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? const {};
          return _slideUp(
            InCallScreen(
              matchId:   state.pathParameters['matchId']!,
              callType:  extra['callType'] as CallType? ?? CallType.videoChaperoned,
              myName:    extra['myName']    as String?  ?? '',
              otherName: extra['otherName'] as String?  ?? '',
            ),
            state,
          );
        },
      ),
      // RingingScreen: `extra` must be a Map<String, dynamic> with keys
      //   callerName, callType, participantType, myName
      GoRoute(
        path: AppRoutes.callRinging,
        pageBuilder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? const {};
          return _slideUp(
            RingingScreen(
              callId:          state.pathParameters['callId']!,
              callerName:      extra['callerName']      as String?  ?? '',
              callType:        extra['callType']        as CallType? ?? CallType.videoChaperoned,
              participantType: extra['participantType'] as String?  ?? 'receiver',
              myName:          extra['myName']          as String?  ?? '',
            ),
            state,
          );
        },
      ),

      // ── Match detail + sub-routes ───────────────
      GoRoute(
        path: AppRoutes.match,
        pageBuilder: (_, state) => _slideRight(
          MatchScreen(matchId: state.pathParameters['matchId']!),
          state,
        ),
        routes: [
          // Chat — slide up
          GoRoute(
            path: 'chat',
            pageBuilder: (_, state) => _slideUp(
              ChatScreen(matchId: state.pathParameters['matchId']!),
              state,
            ),
          ),
          // Games — slide right for hub, slide right for play
          GoRoute(
            path: 'games',
            pageBuilder: (_, state) => _slideRight(
              GameHubScreen(matchId: state.pathParameters['matchId']!),
              state,
            ),
            routes: [
              GoRoute(
                path: ':gameType',
                pageBuilder: (_, state) => _slideRight(
                  GamePlayScreen(
                    matchId:  state.pathParameters['matchId']!,
                    gameType: state.pathParameters['gameType']!,
                  ),
                  state,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Route not found: ${state.uri}')),
    ),
  );
});
