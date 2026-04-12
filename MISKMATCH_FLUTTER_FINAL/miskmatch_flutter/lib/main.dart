import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/api/api_client.dart';
import 'core/providers/locale_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/notifications/notification_service.dart';
import 'features/auth/providers/auth_provider.dart';
import 'l10n/generated/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init failed (missing google-services.json?): $e');
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness:     Brightness.light,
    ),
  );

  ErrorWidget.builder = (FlutterErrorDetails details) =>
      _MiskMatchErrorWidget(message: details.exceptionAsString());

  runApp(const ProviderScope(child: MiskMatchApp()));
}

class MiskMatchApp extends ConsumerStatefulWidget {
  const MiskMatchApp({super.key});

  @override
  ConsumerState<MiskMatchApp> createState() => _MiskMatchAppState();
}

class _MiskMatchAppState extends ConsumerState<MiskMatchApp>
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).checkSession();
      NotificationService.init(
        ref.read(routerProvider),
        dio: ref.read(dioProvider),
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);
    return MaterialApp.router(
      title:                      'MiskMatch',
      debugShowCheckedModeBanner: false,
      routerConfig:               router,
      theme:                      AppTheme.roseGardenTheme,
      darkTheme:                  AppTheme.muskNightTheme,
      themeMode:                  ThemeMode.system,
      scrollBehavior:             const _MiskScrollBehavior(),
      locale:                     locale, // null = follow system
      builder: (context, child) => child!,
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
        Locale('ar', 'JO'),
        Locale('ar', 'SA'),
        Locale('ar', 'AE'),
        Locale('ar', 'GB'),
      ],
    );
  }
}

class _MiskScrollBehavior extends ScrollBehavior {
  const _MiskScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildOverscrollIndicator(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child;
}

class _MiskMatchErrorWidget extends StatelessWidget {
  const _MiskMatchErrorWidget({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    // Null-safe: localizations may be unavailable if this fires during early init.
    final l = S.of(context);
    final title = l?.somethingWentWrong ?? 'Something went wrong';
    final body  = l?.pleaseRestartApp
        ?? 'Please restart the app.\nWe apologise for the inconvenience.';

    return Material(
      color: const Color(0xFFFBF0F3),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 80, height: 80,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFF8B1A4A), Color(0xFFC4436A)]),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('مـ',
                    style: TextStyle(
                      fontFamily: 'Scheherazade', fontSize: 36,
                      color: Colors.white, fontWeight: FontWeight.w700,
                    )),
              ),
            ),
            const SizedBox(height: 24),
            Text(title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E)),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(body,
                style: const TextStyle(fontSize: 14, color: Color(0xFF8A8AAA), height: 1.6),
                textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}
