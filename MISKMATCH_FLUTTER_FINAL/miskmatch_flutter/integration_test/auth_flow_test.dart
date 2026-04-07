// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mocktail/mocktail.dart';

import 'package:miskmatch/core/router/app_router.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/storage/secure_storage.dart';
import 'package:miskmatch/features/auth/providers/auth_provider.dart';
import 'package:miskmatch/features/auth/data/auth_repository.dart';
import 'package:miskmatch/features/auth/data/auth_models.dart';
import 'package:miskmatch/shared/models/api_response.dart';

// ─────────────────────────────────────────────
// MOCKS
// ─────────────────────────────────────────────

class MockSecureStorage extends Mock implements SecureStorage {}

class FakeRegisterRequest extends Fake implements RegisterRequest {}

class FakeLoginRequest extends Fake implements LoginRequest {}

class FakeOtpVerifyRequest extends Fake implements OtpVerifyRequest {}

class MockAuthRepository extends Mock implements AuthRepository {}

// ─────────────────────────────────────────────
// TEST APP — no Firebase, no FCM
// ─────────────────────────────────────────────

class TestMiskMatchApp extends ConsumerWidget {
  const TestMiskMatchApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'MiskMatch Test',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.roseGardenTheme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', 'US')],
    );
  }
}

// ─────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────

/// Pump multiple frames. Safe with infinite animations
/// (LinearProgressIndicator, flutter_animate, Timer.periodic)
/// where pumpAndSettle would hang.
Future<void> settle(WidgetTester tester, [int frames = 10]) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    // Yield to avoid "guarded function conflict" in LiveTestWidgetsFlutterBinding
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthRepository mockRepo;
  late MockSecureStorage mockStorage;

  setUpAll(() {
    registerFallbackValue(FakeRegisterRequest());
    registerFallbackValue(FakeLoginRequest());
    registerFallbackValue(FakeOtpVerifyRequest());
  });

  setUp(() {
    mockRepo = MockAuthRepository();
    mockStorage = MockSecureStorage();

    // Default: no active session
    when(() => mockRepo.hasActiveSession()).thenAnswer((_) async => false);
    when(() => mockRepo.storage).thenReturn(mockStorage);
    when(() => mockStorage.getUserId()).thenAnswer((_) async => null);
    when(() => mockStorage.hasValidTokens()).thenAnswer((_) async => false);
    when(() => mockStorage.getAccessToken())
        .thenAnswer((_) async => 'test-access-token');
    when(() => mockStorage.getRefreshToken())
        .thenAnswer((_) async => 'test-refresh-token');

    // Register → success (OTP sent)
    when(() => mockRepo.register(any())).thenAnswer(
      (_) async => const ApiSuccess('OTP sent to your phone.'),
    );

    // Verify OTP → success (authenticated with tokens)
    when(() => mockRepo.verifyOtp(any())).thenAnswer(
      (_) async => const ApiSuccess(AuthTokens(
        accessToken: 'test-access-token',
        refreshToken: 'test-refresh-token',
        userId: 'test-user-123',
        tokenType: 'bearer',
      )),
    );

    // Login → success
    when(() => mockRepo.login(any())).thenAnswer(
      (_) async => const ApiSuccess(AuthTokens(
        accessToken: 'test-access-token',
        refreshToken: 'test-refresh-token',
        userId: 'existing-user-456',
        tokenType: 'bearer',
      )),
    );

    // Token storage — accept any saves silently
    when(() => mockStorage.saveTokens(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
          userId: any(named: 'userId'),
        )).thenAnswer((_) async {});
  });

  Widget buildTestApp() {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockRepo),
        secureStorageProvider.overrideWithValue(mockStorage),
      ],
      child: const TestMiskMatchApp(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TEST 1: Full registration flow
  //   phone → OTP → niyyah → wali skip → discovery
  // ═══════════════════════════════════════════════════════════════════

  testWidgets('Full registration auth flow reaches discovery',
      (tester) async {
    await tester.pumpWidget(buildTestApp());
    await settle(tester);

    // Move to AuthUnauthenticated so router redirects to phone screen
    final element = tester.element(find.byType(TestMiskMatchApp));
    final container = ProviderScope.containerOf(element);
    await container.read(authProvider.notifier).checkSession();
    await settle(tester);

    // ── PHONE SCREEN ──────────────────────────────────────────────
    expect(find.text('Create account'), findsOneWidget);
    print('✓ Phone screen loaded');

    // Fill phone number
    final phoneField = find.widgetWithText(TextFormField, 'Phone number');
    expect(phoneField, findsOneWidget);
    await tester.enterText(phoneField, '+962791234567');
    await tester.pump();

    // Fill password
    final passwordField = find.widgetWithText(TextFormField, 'Password');
    expect(passwordField, findsOneWidget);
    await tester.enterText(passwordField, 'TestPass123');
    await tester.pump();

    // Tap "Create account"
    await tester.tap(find.text('Create account'));
    await settle(tester);
    await settle(tester); // extra settle for route transition

    print('✓ Registration submitted');

    // ── OTP SCREEN ────────────────────────────────────────────────
    expect(find.text('Verify your number'), findsOneWidget);
    print('✓ OTP screen loaded');

    // Enter OTP — PinCodeTextField uses a hidden TextField
    final otpFields = find.byType(TextField);
    expect(otpFields, findsWidgets);
    await tester.enterText(otpFields.first, '123456');
    await settle(tester);
    await settle(tester);

    print('✓ OTP submitted');

    // ── NIYYAH SCREEN ─────────────────────────────────────────────
    await settle(tester);
    expect(find.textContaining('Actions are judged by intentions'),
        findsOneWidget);
    print('✓ Niyyah screen loaded');

    // Tap commitment checkbox
    final checkbox = find.byType(Checkbox);
    expect(checkbox, findsOneWidget);
    await tester.tap(checkbox);
    await settle(tester);

    // Scroll to and tap "Bismillah — Begin"
    final bismillahBtn = find.text('Bismillah — Begin');
    await tester.ensureVisible(bismillahBtn);
    await tester.pump();
    await tester.tap(bismillahBtn);
    await settle(tester);

    print('✓ Niyyah completed');

    // ── WALI SETUP SCREEN ─────────────────────────────────────────
    expect(find.text('Set up your Wali'), findsOneWidget);
    print('✓ Wali setup screen loaded');

    // Skip wali setup
    final skipBtn = find.text('Skip — set up guardian later');
    await tester.ensureVisible(skipBtn);
    await tester.pump();
    await tester.tap(skipBtn);
    await settle(tester);

    // Wali calls context.go(discovery) but router redirect sees
    // needsOnboarding=true. Simulate onboarding completion.
    container.read(authProvider.notifier).state = const AuthAuthenticated(
      userId: 'test-user-123',
      needsOnboarding: false,
    );
    await settle(tester);
    await settle(tester);

    // ── DISCOVERY SCREEN ──────────────────────────────────────────
    expect(find.text('Discover'), findsWidgets);
    print('✓ Discovery screen reached — full auth flow complete!');
  });

  // ═══════════════════════════════════════════════════════════════════
  // TEST 2: Wali form submission flow
  // ═══════════════════════════════════════════════════════════════════

  testWidgets('Wali form submission reaches discovery', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await settle(tester);

    final element = tester.element(find.byType(TestMiskMatchApp));
    final container = ProviderScope.containerOf(element);

    // Start as authenticated needing onboarding → niyyah
    container.read(authProvider.notifier).state = const AuthAuthenticated(
      userId: 'test-user-123',
      needsOnboarding: true,
    );
    await settle(tester);

    // Skip niyyah
    final skipNiyyah = find.text('Skip for now');
    if (skipNiyyah.evaluate().isNotEmpty) {
      await tester.ensureVisible(skipNiyyah);
      await tester.pump();
      await tester.tap(skipNiyyah);
      await settle(tester);
    }

    // ── WALI SETUP ────────────────────────────────────────────────
    expect(find.text('Set up your Wali'), findsOneWidget);

    // Fill guardian name
    final nameField = find.widgetWithText(TextFormField, 'Guardian name');
    expect(nameField, findsOneWidget);
    await tester.enterText(nameField, 'Ahmad Al-Rashidi');
    await tester.pump();

    // Fill guardian phone
    final phoneField =
        find.widgetWithText(TextFormField, 'Phone with country code');
    expect(phoneField, findsOneWidget);
    await tester.enterText(phoneField, '+962791112222');
    await tester.pump();

    // Submit
    final submitBtn = find.text('Set up guardian & continue');
    await tester.ensureVisible(submitBtn);
    await tester.pump();
    await tester.tap(submitBtn);

    // Wait for 1-second simulated API delay
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Simulate onboarding completion
    container.read(authProvider.notifier).state = const AuthAuthenticated(
      userId: 'test-user-123',
      needsOnboarding: false,
    );
    await settle(tester);
    await settle(tester);

    expect(find.text('Discover'), findsWidgets);
    print('✓ Wali form submission flow complete!');
  });

  // ═══════════════════════════════════════════════════════════════════
  // TEST 3: Login flow (existing user, no onboarding)
  // ═══════════════════════════════════════════════════════════════════

  testWidgets('Login flow for existing user reaches discovery',
      (tester) async {
    await tester.pumpWidget(buildTestApp());
    await settle(tester);

    final element = tester.element(find.byType(TestMiskMatchApp));
    final container = ProviderScope.containerOf(element);
    await container.read(authProvider.notifier).checkSession();
    await settle(tester);

    // ── PHONE SCREEN ──────────────────────────────────────────────
    expect(find.text('Create account'), findsOneWidget);

    // Switch to "Sign in" tab
    await tester.tap(find.text('Sign in'));
    await settle(tester);

    // Fill phone
    final phoneField = find.widgetWithText(TextFormField, 'Phone number');
    await tester.enterText(phoneField, '+962791234567');
    await tester.pump();

    // Fill password
    final passwordField = find.widgetWithText(TextFormField, 'Password');
    await tester.enterText(passwordField, 'TestPass123');
    await tester.pump();

    // Tap the Sign in button (ElevatedButton, not the tab)
    final signInBtn = find.widgetWithText(ElevatedButton, 'Sign in');
    expect(signInBtn, findsOneWidget);
    await tester.tap(signInBtn);
    await settle(tester);
    await settle(tester);

    // Login → AuthAuthenticated(needsOnboarding: false) → discovery
    expect(find.text('Discover'), findsWidgets);
    print('✓ Login flow reached discovery!');
  });

  // ═══════════════════════════════════════════════════════════════════
  // TEST 4: Niyyah suggestion chip auto-fills text
  // ═══════════════════════════════════════════════════════════════════

  testWidgets('Niyyah suggestion chip fills text field', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await settle(tester);

    final element = tester.element(find.byType(TestMiskMatchApp));
    final container = ProviderScope.containerOf(element);
    container.read(authProvider.notifier).state = const AuthAuthenticated(
      userId: 'test-user-123',
      needsOnboarding: true,
    );
    await settle(tester);

    // Should be on niyyah screen
    expect(find.textContaining('Actions are judged by intentions'),
        findsOneWidget);

    // Tap first suggestion chip (truncated to 40 chars in UI)
    final chip = find.textContaining('To find a righteous spouse');
    expect(chip, findsOneWidget);
    await tester.tap(chip);
    await settle(tester);

    // Verify text field was filled
    final niyyahField = find.widgetWithText(TextFormField, 'Your niyyah');
    expect(niyyahField, findsOneWidget);
    final textField = tester.widget<TextFormField>(niyyahField);
    expect(textField.controller?.text, contains('righteous spouse'));

    print('✓ Niyyah suggestion chip auto-fills correctly!');
  });
}
