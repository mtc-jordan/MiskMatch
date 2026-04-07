import 'package:dio/dio.dart';
import '../../storage/secure_storage.dart';

/// Injects the stored access token as a Bearer header on every request.
/// Skips auth header for public endpoints (login, register, OTP).

const _publicPaths = {
  '/auth/register',
  '/auth/login',
  '/auth/verify-otp',
  '/auth/refresh',
  '/auth/resend-otp',
};

class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.storage});

  final SecureStorage storage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Don't inject token for public auth endpoints
    final path = options.path;
    final isPublic = _publicPaths.any((p) => path.endsWith(p));

    if (!isPublic) {
      final token = await storage.getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }

    handler.next(options);
  }
}
