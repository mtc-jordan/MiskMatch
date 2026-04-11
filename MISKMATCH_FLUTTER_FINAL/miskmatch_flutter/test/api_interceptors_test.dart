import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:miskmatch/core/api/interceptors/auth_interceptor.dart';
import 'package:miskmatch/core/storage/secure_storage.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Mocks
// ─────────────────────────────────────────────────────────────────────────────

class MockSecureStorage extends Mock implements SecureStorage {}

class MockRequestInterceptorHandler extends Mock
    implements RequestInterceptorHandler {}

void main() {
  late MockSecureStorage mockStorage;
  late AuthInterceptor interceptor;
  late MockRequestInterceptorHandler mockHandler;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: '/'));
  });

  setUp(() {
    mockStorage = MockSecureStorage();
    interceptor = AuthInterceptor(storage: mockStorage);
    mockHandler = MockRequestInterceptorHandler();
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // AuthInterceptor
  // ═══════════════════════════════════════════════════════════════════════════

  group('AuthInterceptor', () {
    test('adds Bearer token for protected endpoints', () async {
      when(() => mockStorage.getAccessToken())
          .thenAnswer((_) async => 'test-jwt-token');

      final options = RequestOptions(path: '/profiles/me');
      await interceptor.onRequest(options, mockHandler);

      expect(options.headers['Authorization'], 'Bearer test-jwt-token');
      verify(() => mockHandler.next(options)).called(1);
    });

    test('skips token for /auth/register', () async {
      final options = RequestOptions(path: '/api/v1/auth/register');
      await interceptor.onRequest(options, mockHandler);

      expect(options.headers.containsKey('Authorization'), false);
      verifyNever(() => mockStorage.getAccessToken());
      verify(() => mockHandler.next(options)).called(1);
    });

    test('skips token for /auth/login', () async {
      final options = RequestOptions(path: '/api/v1/auth/login');
      await interceptor.onRequest(options, mockHandler);

      expect(options.headers.containsKey('Authorization'), false);
    });

    test('skips token for /auth/verify-otp', () async {
      final options = RequestOptions(path: '/api/v1/auth/verify-otp');
      await interceptor.onRequest(options, mockHandler);

      expect(options.headers.containsKey('Authorization'), false);
    });

    test('skips token for /auth/refresh', () async {
      final options = RequestOptions(path: '/api/v1/auth/refresh');
      await interceptor.onRequest(options, mockHandler);

      expect(options.headers.containsKey('Authorization'), false);
    });

    test('skips token for /auth/resend-otp', () async {
      final options = RequestOptions(path: '/api/v1/auth/resend-otp');
      await interceptor.onRequest(options, mockHandler);

      expect(options.headers.containsKey('Authorization'), false);
    });

    test('does not add header when no token stored', () async {
      when(() => mockStorage.getAccessToken())
          .thenAnswer((_) async => null);

      final options = RequestOptions(path: '/profiles/me');
      await interceptor.onRequest(options, mockHandler);

      expect(options.headers.containsKey('Authorization'), false);
      verify(() => mockHandler.next(options)).called(1);
    });

    test('adds token for match endpoints', () async {
      when(() => mockStorage.getAccessToken())
          .thenAnswer((_) async => 'jwt-abc');

      final options = RequestOptions(path: '/matches/discover');
      await interceptor.onRequest(options, mockHandler);

      expect(options.headers['Authorization'], 'Bearer jwt-abc');
    });

    test('adds token for messages endpoint', () async {
      when(() => mockStorage.getAccessToken())
          .thenAnswer((_) async => 'jwt-xyz');

      final options = RequestOptions(path: '/messages/some-match-id');
      await interceptor.onRequest(options, mockHandler);

      expect(options.headers['Authorization'], 'Bearer jwt-xyz');
    });
  });
}
