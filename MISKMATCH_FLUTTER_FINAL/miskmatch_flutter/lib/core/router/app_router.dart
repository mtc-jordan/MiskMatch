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
import 'package:miskmatch/features/chat/screens/chat_screen.dart';
import 'package:miskmatch/features/games/screens/game_hub_screen.dart';
import 'package:miskmatch/features/games/screens/game_play_screen.dart';
import 'package:miskmatch/features/wali/screens/wali_dashboard_screen.dart';
import 'package:miskmatch/features/profile/screens/profile_screen.dart';
import 'package:miskmatch/features/profile/screens/profile_edit_screen.dart';
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
  static const wali        = '/wali';
  static const profile     = '/profile';
  static const profileEdit = '/profile/edit';
  static const settings    = '/settings';

  static String matchPath(String id)   => '/match/$id';
  static String chatPath(String id)    => '/match/$id/chat';
  static String gameHubPath(String id) => '/match/$id/games';
  static String gamePlayPath(String matchId, String type) => '/match/$matchId/games/$type';
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    redirect: (context, state) {
      final loc  = state.matchedLocation;
      final auth = authState;
      final isAuthRoute = loc.startsWith('/auth');
      final isSplash    = loc == AppRoutes.splash;

      if (auth is AuthInitial)          return isSplash ? null : AppRoutes.splash;
      if (auth is AuthUnauthenticated)  return isAuthRoute ? null : AppRoutes.phone;
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
      GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: AppRoutes.phone,  builder: (_, __) => const PhoneScreen()),
      GoRoute(
        path: AppRoutes.otp,
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return OtpScreen(
            phone:     extra?['phone']     as String? ?? '',
            isNewUser: extra?['isNewUser'] as bool?   ?? true,
          );
        },
      ),
      GoRoute(path: AppRoutes.niyyah,   builder: (_, __) => const NiyyahScreen()),
      GoRoute(path: AppRoutes.waliSetup,builder: (_, __) => const WaliSetupScreen()),

      // Main shell with bottom nav
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: AppRoutes.discovery, builder: (_, __) => const DiscoveryScreen()),
          GoRoute(path: AppRoutes.matches,   builder: (_, __) => const MatchesListScreen()),
          GoRoute(path: AppRoutes.wali,      builder: (_, __) => const WaliDashboardScreen()),
          GoRoute(
            path: AppRoutes.profile,
            builder: (_, __) => const ProfileScreen(),
            routes: [
              GoRoute(path: 'edit', builder: (_, __) => const ProfileEditScreen()),
            ],
          ),
        ],
      ),

      // Match detail + chat (full screen)
      GoRoute(
        path: AppRoutes.match,
        builder: (_, state) =>
            MatchScreen(matchId: state.pathParameters['matchId']!),
        routes: [
          GoRoute(
            path: 'chat',
            builder: (_, state) =>
                ChatScreen(matchId: state.pathParameters['matchId']!),
          ),
          GoRoute(
            path: 'games',
            builder: (_, state) =>
                GameHubScreen(matchId: state.pathParameters['matchId']!),
            routes: [
              GoRoute(
                path: ':gameType',
                builder: (_, state) => GamePlayScreen(
                  matchId:  state.pathParameters['matchId']!,
                  gameType: state.pathParameters['gameType']!,
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
