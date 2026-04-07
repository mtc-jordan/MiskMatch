import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miskmatch/core/api/api_client.dart';
import 'package:miskmatch/shared/models/api_response.dart';
import 'call_models.dart';

class CallRepository {
  CallRepository(this._dio);
  final Dio _dio;

  // ── Initiate call ─────────────────────────────────────────────────────────
  Future<ApiResult<CallModel>> initiateCall(InitiateCallRequest req) async {
    try {
      final res = await _dio.post('/calls/initiate', data: req.toJson());
      if (res.statusCode == 200) {
        return ApiSuccess(CallModel.fromJson(res.data as Map<String, dynamic>));
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Join call ─────────────────────────────────────────────────────────────
  Future<ApiResult<CallModel>> joinCall(
      String callId, String participantType) async {
    try {
      final res = await _dio.post(
        '/calls/$callId/join',
        data: {'participant_type': participantType},
      );
      if (res.statusCode == 200) {
        return ApiSuccess(CallModel.fromJson(res.data as Map<String, dynamic>));
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── End call ──────────────────────────────────────────────────────────────
  Future<ApiResult<CallModel>> endCall(String callId,
      {String? reason}) async {
    try {
      final res = await _dio.post(
        '/calls/$callId/end',
        data: {'reason': reason ?? 'completed'},
      );
      if (res.statusCode == 200) {
        return ApiSuccess(CallModel.fromJson(res.data as Map<String, dynamic>));
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Get call ──────────────────────────────────────────────────────────────
  Future<ApiResult<CallModel>> getCall(String callId) async {
    try {
      final res = await _dio.get('/calls/$callId');
      if (res.statusCode == 200) {
        return ApiSuccess(CallModel.fromJson(res.data as Map<String, dynamic>));
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Call history for a match ──────────────────────────────────────────────
  Future<ApiResult<List<CallModel>>> getMatchHistory(String matchId) async {
    try {
      final res = await _dio.get('/calls/match/$matchId');
      if (res.statusCode == 200) {
        final data  = res.data as Map<String, dynamic>;
        final calls = (data['calls'] as List<dynamic>? ?? [])
            .map((e) => CallModel.fromJson(e as Map<String, dynamic>))
            .toList();
        return ApiSuccess(calls);
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Wali approve ──────────────────────────────────────────────────────────
  Future<ApiResult<String>> waliApprove(
      String callId, bool approved) async {
    try {
      final res = await _dio.post(
        '/calls/$callId/wali-approve',
        queryParameters: {'approved': approved},
      );
      if (res.statusCode == 200) {
        return ApiSuccess(res.data['message'] as String? ?? '');
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }
}

final callRepositoryProvider = Provider<CallRepository>(
    (ref) => CallRepository(ref.watch(dioProvider)));
