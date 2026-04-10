import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
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

    // Certificate pinning in production/staging
    if (!AppConfig.isDev && !kIsWeb) {
      _applyCertificatePinning(dio);
    }

    return dio;
  }

  /// Pin the API server's SSL certificate by SHA-256 fingerprint.
  /// Update these fingerprints when certificates are rotated.
  static void _applyCertificatePinning(Dio dio) {
    // SHA-256 fingerprints of the API server's leaf certificate.
    // To get your cert fingerprint:
    //   openssl s_client -connect api.miskmatch.app:443 < /dev/null 2>/dev/null |
    //     openssl x509 -fingerprint -sha256 -noout
    const pinnedFingerprints = <String>{
      // Primary cert (replace with your actual fingerprint before production)
      // Format: 'AA:BB:CC:DD:...' (uppercase hex with colons)
    };

    if (pinnedFingerprints.isEmpty) {
      // No fingerprints configured — skip pinning (log in debug)
      debugPrint('Certificate pinning: no fingerprints configured, skipping');
      return;
    }

    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (X509Certificate cert, String host, int port) {
        // Only pin for our API hosts
        if (!host.endsWith('miskmatch.app')) return false;

        final fingerprint = cert.sha256.map(
          (b) => b.toRadixString(16).padLeft(2, '0').toUpperCase(),
        ).join(':');

        return pinnedFingerprints.contains(fingerprint);
      };
      return client;
    };
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return ApiClient.create(storage: storage);
});
