import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Pretty-prints requests and responses in debug mode.
/// Automatically disabled in production (see api_client.dart).

class LoggingInterceptor extends Interceptor {
  static const _sensitiveFields = {'password', 'token', 'access_token', 'refresh_token', 'otp'};

  /// Redact sensitive fields from request body before logging.
  dynamic _redactBody(dynamic data) {
    if (data is Map) {
      return data.map((key, value) {
        if (_sensitiveFields.contains(key)) return MapEntry(key, '***');
        return MapEntry(key, value);
      });
    }
    return data;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('┌─────────────────────────────────────────');
    debugPrint('│ ${options.method} ${options.uri}');
    if (options.data != null) {
      debugPrint('│ Body: ${_redactBody(options.data)}');
    }
    debugPrint('└─────────────────────────────────────────');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final ok = response.statusCode != null && response.statusCode! < 300;
    debugPrint('┌─────────────────────────────────────────');
    debugPrint('│ ${ok ? "OK" : "WARN"} ${response.statusCode} '
        '${response.requestOptions.method} ${response.requestOptions.path}');
    final body = response.data.toString();
    debugPrint('│ Body: ${body.substring(0, body.length.clamp(0, 200))}...');
    debugPrint('└─────────────────────────────────────────');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('┌─────────────────────────────────────────');
    debugPrint('│ ERROR ${err.response?.statusCode} '
        '${err.requestOptions.method} ${err.requestOptions.path}');
    debugPrint('│ Error: ${err.message}');
    if (err.response?.data != null) {
      debugPrint('│ Detail: ${err.response?.data}');
    }
    debugPrint('└─────────────────────────────────────────');
    handler.next(err);
  }
}
