import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/env.dart';
import '../storage/secure_storage.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/refresh_interceptor.dart';
import 'interceptors/logging_interceptor.dart';

/// MiskMatch API Client
///
/// Dio instance configured with:
///   - Base URL from AppConfig (dev/staging/prod)
///   - JWT Bearer token injection on every request
///   - Automatic token refresh on 401
///   - Request/response logging in dev
///   - Timeout configuration
///   - Standard headers (Content-Type, Accept, Accept-Language)

class ApiClient {
  ApiClient._();

  static Dio create({
    required SecureStorage storage,
    String? baseUrl,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl:        baseUrl ?? AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        sendTimeout:    AppConfig.uploadTimeout,
        headers: {
          'Content-Type':  'application/json',
          'Accept':        'application/json',
          'Accept-Language': 'ar,en;q=0.9',
          'X-App-Name':   AppConfig.appName,
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    // Add interceptors in order:
    // 1. Auth — injects Bearer token
    // 2. Refresh — catches 401, refreshes token, retries
    // 3. Logging — only in dev

    dio.interceptors.addAll([
      AuthInterceptor(storage: storage),
      RefreshInterceptor(dio: dio, storage: storage),
      if (AppConfig.isDev) LoggingInterceptor(),
    ]);

    return dio;
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return ApiClient.create(storage: storage);
});
