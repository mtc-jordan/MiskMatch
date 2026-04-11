import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miskmatch/core/api/api_client.dart';
import 'package:miskmatch/core/api/api_endpoints.dart';
import 'package:miskmatch/shared/models/api_response.dart';
import 'wali_models.dart';

class WaliRepository {
  WaliRepository(this._dio);
  final Dio _dio;

  // ── Guardian dashboard ────────────────────────────────────────────────────
  Future<ApiResult<WaliDashboard>> getDashboard() async {
    try {
      final res = await _dio.get(ApiEndpoints.waliDashboard,
        options: Options(receiveTimeout: const Duration(seconds: 3)),
      );
      if (res.statusCode == 200) {
        return ApiSuccess(
            WaliDashboard.fromJson(res.data as Map<String, dynamic>));
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Wards list ────────────────────────────────────────────────────────────
  Future<ApiResult<List<Ward>>> getWards() async {
    try {
      final res = await _dio.get(ApiEndpoints.waliWards,
        options: Options(receiveTimeout: const Duration(seconds: 3)),
      );
      if (res.statusCode == 200) {
        final data  = res.data as Map<String, dynamic>;
        final items = (data['wards'] as List<dynamic>? ?? [])
            .map((e) => Ward.fromJson(e as Map<String, dynamic>))
            .toList();
        return ApiSuccess(items);
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Pending decisions ─────────────────────────────────────────────────────
  Future<ApiResult<List<WaliMatchDecision>>> getPendingDecisions() async {
    try {
      final res = await _dio.get(ApiEndpoints.waliPending,
        options: Options(receiveTimeout: const Duration(seconds: 3)),
      );
      if (res.statusCode == 200) {
        final data  = res.data as Map<String, dynamic>;
        final items = (data['decisions'] as List<dynamic>? ?? [])
            .map((e) => WaliMatchDecision.fromJson(e as Map<String, dynamic>))
            .toList();
        return ApiSuccess(items);
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Decide on a match ─────────────────────────────────────────────────────
  Future<ApiResult<String>> decide(WaliDecisionRequest req) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.waliDecide(req.matchId),
        data: req.toJson(),
      );
      if (res.statusCode == 200) {
        final msg = req.approved
            ? 'Alhamdulillah — Match approved. May Allah bless this union.'
            : 'Noted. The match has been respectfully declined.';
        return ApiSuccess(msg);
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Wali setup ────────────────────────────────────────────────────────────
  Future<ApiResult<WaliStatus>> setup(WaliSetupRequest req) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.waliSetup,
        data: req.toJson(),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        return ApiSuccess(
            WaliStatus.fromJson(res.data as Map<String, dynamic>));
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Wali status ───────────────────────────────────────────────────────────
  Future<ApiResult<WaliStatus>> getStatus() async {
    try {
      final res = await _dio.get(ApiEndpoints.waliStatus,
        options: Options(receiveTimeout: const Duration(seconds: 3)),
      );
      if (res.statusCode == 200) {
        return ApiSuccess(
            WaliStatus.fromJson(res.data as Map<String, dynamic>));
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Accept wali invite ────────────────────────────────────────────────────
  Future<ApiResult<String>> acceptInvite(String token) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.waliAccept,
        data: {'token': token},
      );
      if (res.statusCode == 200) {
        return const ApiSuccess('Welcome to MiskMatch Guardian Portal.');
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Update permissions ────────────────────────────────────────────────────
  Future<ApiResult<WaliPermissions>> updatePermissions(
      WaliPermissions permissions) async {
    try {
      final res = await _dio.put(
        ApiEndpoints.waliPermissions,
        data: permissions.toJson(),
      );
      if (res.statusCode == 200) {
        return ApiSuccess(WaliPermissions.fromJson(
            res.data as Map<String, dynamic>));
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Conversations (read messages as wali) ─────────────────────────────────
  Future<ApiResult<List<WaliConversation>>> getConversations() async {
    try {
      final res = await _dio.get(ApiEndpoints.waliConversations,
        options: Options(receiveTimeout: const Duration(seconds: 3)),
      );
      if (res.statusCode == 200) {
        final data  = res.data as Map<String, dynamic>;
        final items = (data['conversations'] as List<dynamic>? ?? [])
            .map((e) => WaliConversation.fromJson(e as Map<String, dynamic>))
            .toList();
        return ApiSuccess(items);
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Resend invite SMS ─────────────────────────────────────────────────────
  Future<ApiResult<String>> resendInvite() async {
    try {
      final res = await _dio.post(ApiEndpoints.waliInviteResend);
      if (res.statusCode == 200) {
        return const ApiSuccess('Invitation resent to your guardian.');
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }
}

final waliRepositoryProvider = Provider<WaliRepository>(
    (ref) => WaliRepository(ref.watch(dioProvider)));
