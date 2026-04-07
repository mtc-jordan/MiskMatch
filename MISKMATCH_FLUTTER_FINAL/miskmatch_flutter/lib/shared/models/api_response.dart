import 'package:dio/dio.dart';

/// Typed API response wrapper — every repository call returns this.
/// Forces the UI layer to handle both success and error states.

sealed class ApiResult<T> {
  const ApiResult();
}

final class ApiSuccess<T> extends ApiResult<T> {
  const ApiSuccess(this.data);
  final T data;
}

final class ApiError<T> extends ApiResult<T> {
  const ApiError(this.error);
  final AppError error;
}

/// Structured application error.
class AppError {
  const AppError({
    required this.message,
    this.messageAr,
    this.statusCode,
    this.field,
    this.type = AppErrorType.unknown,
  });

  final String       message;
  final String?      messageAr;
  final int?         statusCode;
  final String?      field;       // validation field name
  final AppErrorType type;

  bool get isNetwork     => type == AppErrorType.network;
  bool get isAuth        => type == AppErrorType.auth;
  bool get isValidation  => type == AppErrorType.validation;
  bool get isNotFound    => type == AppErrorType.notFound;
  bool get isServer      => type == AppErrorType.server;

  @override
  String toString() => 'AppError($type, $statusCode): $message';

  /// Parse from Dio exception
  factory AppError.fromDio(DioException e) {
    final status = e.response?.statusCode;
    final data   = e.response?.data;

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.connectionError:
        return const AppError(
          message:   'No internet connection. Please check your network.',
          messageAr: 'لا يوجد اتصال بالإنترنت. يرجى التحقق من شبكتك.',
          type:      AppErrorType.network,
        );

      case DioExceptionType.badResponse:
        return AppError.fromResponse(status, data);

      default:
        return AppError(
          message:    e.message ?? 'An unexpected error occurred.',
          statusCode: status,
          type:       AppErrorType.unknown,
        );
    }
  }

  /// Parse from HTTP response data
  factory AppError.fromResponse(int? statusCode, dynamic data) {
    String message = 'An error occurred. Please try again.';

    if (data is Map<String, dynamic>) {
      // FastAPI validation error format: { detail: [...] }
      final detail = data['detail'];
      if (detail is String) {
        message = detail;
      } else if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map) {
          message = first['message']?.toString() ??
                    first['msg']?.toString() ??
                    message;
        }
      } else if (data['message'] is String) {
        message = data['message'];
      }
    }

    final type = switch (statusCode) {
      400            => AppErrorType.validation,
      401 || 403     => AppErrorType.auth,
      404            => AppErrorType.notFound,
      422            => AppErrorType.validation,
      int s when s >= 500 => AppErrorType.server,
      _              => AppErrorType.unknown,
    };

    return AppError(
      message:    message,
      statusCode: statusCode,
      type:       type,
    );
  }
}

enum AppErrorType {
  network,
  auth,
  validation,
  notFound,
  server,
  unknown,
}

// ─────────────────────────────────────────────
// Extension — safe unwrap helpers
// ─────────────────────────────────────────────

extension ApiResultX<T> on ApiResult<T> {
  bool get isSuccess => this is ApiSuccess<T>;
  bool get isError   => this is ApiError<T>;

  T? get dataOrNull {
    if (this is ApiSuccess<T>) return (this as ApiSuccess<T>).data;
    return null;
  }

  AppError? get errorOrNull {
    if (this is ApiError<T>) return (this as ApiError<T>).error;
    return null;
  }

  R when<R>({
    required R Function(T data) success,
    required R Function(AppError error) error,
  }) {
    return switch (this) {
      ApiSuccess<T> s => success(s.data),
      ApiError<T>   e => error(e.error),
    };
  }
}
