import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:miskmatch/features/auth/data/auth_models.dart';
import 'package:miskmatch/features/auth/data/auth_repository.dart';
import 'package:miskmatch/features/auth/providers/auth_provider.dart';
import 'package:miskmatch/core/storage/secure_storage.dart';
import 'package:miskmatch/shared/models/api_response.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Mocks
// ─────────────────────────────────────────────────────────────────────────────

class MockAuthRepository extends Mock implements AuthRepository {}

class MockSecureStorage extends Mock implements SecureStorage {}

class FakeRegisterRequest extends Fake implements RegisterRequest {}

class FakeLoginRequest extends Fake implements LoginRequest {}

class FakeOtpVerifyRequest extends Fake implements OtpVerifyRequest {}

void main() {
  late MockAuthRepository mockRepo;
  late MockSecureStorage mockStorage;
  late AuthNotifier notifier;

  setUpAll(() {
    registerFallbackValue(FakeRegisterRequest());
    registerFallbackValue(FakeLoginRequest());
    registerFallbackValue(FakeOtpVerifyRequest());
  });

  setUp(() {
    mockRepo = MockAuthRepository();
    mockStorage = MockSecureStorage();
    when(() => mockRepo.storage).thenReturn(mockStorage);
    notifier = AuthNotifier(mockRepo);
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Initial state
  // ═══════════════════════════════════════════════════════════════════════════

  group('Initial state', () {
    test('should be AuthInitial', () {
      expect(notifier.state, isA<AuthInitial>());
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // checkSession
  // ═══════════════════════════════════════════════════════════════════════════

  group('checkSession', () {
    test('with valid tokens transitions to AuthAuthenticated', () async {
      when(() => mockRepo.hasActiveSession()).thenAnswer((_) async => true);
      when(() => mockStorage.getUserId()).thenAnswer((_) async => 'user123');
      when(() => mockStorage.getGender()).thenAnswer((_) async => 'male');

      await notifier.checkSession();

      expect(notifier.state, isA<AuthAuthenticated>());
      final state = notifier.state as AuthAuthenticated;
      expect(state.userId, 'user123');
      expect(state.gender, 'male');
      expect(state.needsOnboarding, false);
    });

    test('without valid tokens transitions to AuthUnauthenticated', () async {
      when(() => mockRepo.hasActiveSession()).thenAnswer((_) async => false);

      await notifier.checkSession();

      expect(notifier.state, isA<AuthUnauthenticated>());
    });

    test('with valid tokens but null userId uses empty string', () async {
      when(() => mockRepo.hasActiveSession()).thenAnswer((_) async => true);
      when(() => mockStorage.getUserId()).thenAnswer((_) async => null);
      when(() => mockStorage.getGender()).thenAnswer((_) async => null);

      await notifier.checkSession();

      expect(notifier.state, isA<AuthAuthenticated>());
      final state = notifier.state as AuthAuthenticated;
      expect(state.userId, '');
      expect(state.gender, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // register
  // ═══════════════════════════════════════════════════════════════════════════

  group('register', () {
    test('success transitions to AuthOtpSent', () async {
      when(() => mockRepo.register(any()))
          .thenAnswer((_) async => const ApiSuccess('OTP sent.'));

      await notifier.register(
        phone: '+966500000000',
        password: 'password123',
        gender: 'male',
      );

      expect(notifier.state, isA<AuthOtpSent>());
      final state = notifier.state as AuthOtpSent;
      expect(state.phone, '+966500000000');
      expect(state.isNewUser, true);
    });

    test('error transitions to AuthError', () async {
      when(() => mockRepo.register(any())).thenAnswer(
        (_) async => ApiError(
          AppError(message: 'Phone already registered', type: AppErrorType.validation),
        ),
      );

      await notifier.register(
        phone: '+966500000000',
        password: 'password123',
        gender: 'male',
      );

      expect(notifier.state, isA<AuthError>());
      final state = notifier.state as AuthError;
      expect(state.error.message, 'Phone already registered');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // login
  // ═══════════════════════════════════════════════════════════════════════════

  group('login', () {
    test('success transitions to AuthAuthenticated', () async {
      when(() => mockRepo.login(any())).thenAnswer(
        (_) async => ApiSuccess(AuthTokens.fromJson({
          'access_token': 'acc',
          'refresh_token': 'ref',
          'user_id': 'user42',
          'token_type': 'bearer',
          'gender': 'male',
          'onboarding_completed': true,
        })),
      );

      await notifier.login(phone: '+966500000000', password: 'pass');

      expect(notifier.state, isA<AuthAuthenticated>());
      final state = notifier.state as AuthAuthenticated;
      expect(state.userId, 'user42');
      expect(state.needsOnboarding, false);
      expect(state.gender, 'male');
    });

    test('login with incomplete onboarding sets needsOnboarding true', () async {
      when(() => mockRepo.login(any())).thenAnswer(
        (_) async => ApiSuccess(AuthTokens.fromJson({
          'access_token': 'acc',
          'refresh_token': 'ref',
          'user_id': 'user42',
          'token_type': 'bearer',
          'gender': 'female',
          'onboarding_completed': false,
        })),
      );

      await notifier.login(phone: '+966500000000', password: 'pass');

      final state = notifier.state as AuthAuthenticated;
      expect(state.needsOnboarding, true);
      expect(state.gender, 'female');
    });

    test('error transitions to AuthError', () async {
      when(() => mockRepo.login(any())).thenAnswer(
        (_) async => ApiError(
          AppError(message: 'Invalid credentials', type: AppErrorType.auth),
        ),
      );

      await notifier.login(phone: '+966500000000', password: 'wrong');

      expect(notifier.state, isA<AuthError>());
      final state = notifier.state as AuthError;
      expect(state.error.message, 'Invalid credentials');
      expect(state.error.type, AppErrorType.auth);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // verifyOtp
  // ═══════════════════════════════════════════════════════════════════════════

  group('verifyOtp', () {
    test('success transitions to AuthAuthenticated', () async {
      when(() => mockRepo.verifyOtp(any())).thenAnswer(
        (_) async => ApiSuccess(AuthTokens.fromJson({
          'access_token': 'acc',
          'refresh_token': 'ref',
          'user_id': 'user99',
          'token_type': 'bearer',
          'gender': 'male',
          'onboarding_completed': false,
        })),
      );

      await notifier.verifyOtp(
        phone: '+966500000000',
        otp: '123456',
        isNewUser: true,
      );

      expect(notifier.state, isA<AuthAuthenticated>());
      final state = notifier.state as AuthAuthenticated;
      expect(state.userId, 'user99');
      expect(state.needsOnboarding, true);
      expect(state.gender, 'male');
    });

    test('existing user verify sets needsOnboarding false', () async {
      when(() => mockRepo.verifyOtp(any())).thenAnswer(
        (_) async => ApiSuccess(AuthTokens.fromJson({
          'access_token': 'acc',
          'refresh_token': 'ref',
          'user_id': 'user99',
          'gender': 'female',
        })),
      );

      await notifier.verifyOtp(
        phone: '+966500000000',
        otp: '123456',
        isNewUser: false,
      );

      final state = notifier.state as AuthAuthenticated;
      expect(state.needsOnboarding, false);
    });

    test('error transitions to AuthError', () async {
      when(() => mockRepo.verifyOtp(any())).thenAnswer(
        (_) async => ApiError(
          AppError(message: 'Invalid OTP', type: AppErrorType.validation),
        ),
      );

      await notifier.verifyOtp(
        phone: '+966500000000',
        otp: '000000',
        isNewUser: true,
      );

      expect(notifier.state, isA<AuthError>());
      final state = notifier.state as AuthError;
      expect(state.error.message, 'Invalid OTP');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // logout
  // ═══════════════════════════════════════════════════════════════════════════

  group('logout', () {
    test('clears state and transitions to AuthUnauthenticated', () async {
      when(() => mockRepo.logout()).thenAnswer((_) async {});

      await notifier.logout();

      expect(notifier.state, isA<AuthUnauthenticated>());
      verify(() => mockRepo.logout()).called(1);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // completeOnboarding
  // ═══════════════════════════════════════════════════════════════════════════

  group('completeOnboarding', () {
    test('sets needsOnboarding to false when authenticated', () async {
      when(() => mockRepo.login(any())).thenAnswer(
        (_) async => ApiSuccess(AuthTokens.fromJson({
          'access_token': 'acc',
          'refresh_token': 'ref',
          'user_id': 'user1',
          'gender': 'male',
          'onboarding_completed': false,
        })),
      );

      await notifier.login(phone: '+966500000000', password: 'pass');
      expect((notifier.state as AuthAuthenticated).needsOnboarding, true);

      notifier.completeOnboarding();

      final state = notifier.state as AuthAuthenticated;
      expect(state.needsOnboarding, false);
      expect(state.userId, 'user1');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // clearError
  // ═══════════════════════════════════════════════════════════════════════════

  group('clearError', () {
    test('transitions from AuthError to AuthUnauthenticated', () async {
      when(() => mockRepo.register(any())).thenAnswer(
        (_) async => ApiError(
          AppError(message: 'fail', type: AppErrorType.unknown),
        ),
      );

      await notifier.register(
        phone: '+966500000000',
        password: 'pass',
        gender: 'male',
      );
      expect(notifier.state, isA<AuthError>());

      notifier.clearError();

      expect(notifier.state, isA<AuthUnauthenticated>());
    });

    test('does nothing when state is not AuthError', () async {
      notifier.clearError();

      expect(notifier.state, isA<AuthInitial>());
    });
  });
}
