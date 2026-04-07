import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Pretty-prints requests and responses in debug mode.
/// Automatically disabled in production (see api_client.dart).

class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('┌─────────────────────────────────────────');
    debugPrint('│ 🌙 ${options.method} ${options.uri}');
    if (options.data != null) {
      debugPrint('│ Body: ${options.data}');
    }
    debugPrint('└─────────────────────────────────────────');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final emoji = response.statusCode != null && response.statusCode! < 300
        ? '✅'
        : '⚠️';
    debugPrint('┌─────────────────────────────────────────');
    debugPrint('│ $emoji ${response.statusCode} '
        '${response.requestOptions.method} ${response.requestOptions.path}');
    debugPrint('│ Body: ${response.data.toString().substring(
        0, response.data.toString().length.clamp(0, 200))}...');
    debugPrint('└─────────────────────────────────────────');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('┌─────────────────────────────────────────');
    debugPrint('│ ❌ ${err.response?.statusCode} '
        '${err.requestOptions.method} ${err.requestOptions.path}');
    debugPrint('│ Error: ${err.message}');
    if (err.response?.data != null) {
      debugPrint('│ Detail: ${err.response?.data}');
    }
    debugPrint('└─────────────────────────────────────────');
    handler.next(err);
  }
}
