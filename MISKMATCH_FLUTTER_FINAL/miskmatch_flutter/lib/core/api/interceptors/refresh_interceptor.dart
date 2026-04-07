import 'package:dio/dio.dart';
import '../../storage/secure_storage.dart';

/// Intercepts 401 Unauthorized responses, silently refreshes the access token
/// using the stored refresh token, then retries the original request.
///
/// If refresh also fails (refresh token expired) → clears storage
/// so the router redirects to login.

class RefreshInterceptor extends Interceptor {
  RefreshInterceptor({required this.dio, required this.storage});

  final Dio       dio;
  final SecureStorage storage;

  // Prevent infinite refresh loops
  bool _isRefreshing = false;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;

    // Only handle 401s that aren't from the refresh endpoint itself
    if (response?.statusCode == 401 &&
        !err.requestOptions.path.contains('/auth/refresh') &&
        !_isRefreshing) {
      _isRefreshing = true;

      try {
        final refreshToken = await storage.getRefreshToken();

        if (refreshToken == null) {
          // No refresh token — force logout
          await storage.clearAll();
          handler.next(err);
          return;
        }

        // Call refresh endpoint
        final refreshDio = Dio(
          BaseOptions(baseUrl: dio.options.baseUrl),
        );
        final refreshResponse = await refreshDio.post(
          '/auth/refresh',
          data: {'refresh_token': refreshToken},
        );

        if (refreshResponse.statusCode == 200) {
          final data         = refreshResponse.data as Map<String, dynamic>;
          final newAccess    = data['access_token']  as String;
          final newRefresh   = data['refresh_token'] as String;

          // Save new tokens
          await storage.saveAccessToken(newAccess);
          await storage.saveRefreshToken(newRefresh);

          // Retry original request with new token
          err.requestOptions.headers['Authorization'] = 'Bearer $newAccess';

          final retryResponse = await dio.fetch(err.requestOptions);
          handler.resolve(retryResponse);
        } else {
          // Refresh failed — logout
          await storage.clearAll();
          handler.next(err);
        }
      } catch (e) {
        // Refresh threw — logout
        await storage.clearAll();
        handler.next(err);
      } finally {
        _isRefreshing = false;
      }
    } else {
      handler.next(err);
    }
  }
}
