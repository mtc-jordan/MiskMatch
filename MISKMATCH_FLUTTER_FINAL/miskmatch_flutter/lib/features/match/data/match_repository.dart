import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miskmatch/core/api/api_client.dart';
import 'package:miskmatch/core/api/api_endpoints.dart';
import 'package:miskmatch/shared/models/api_response.dart';
import 'match_models.dart';

class MatchRepository {
  MatchRepository(this._dio);
  final Dio _dio;

  // ── List all my matches ───────────────────────────────────────────────────
  Future<ApiResult<List<Match>>> getMatches() async {
    try {
      final res = await _dio.get(ApiEndpoints.matchList);
      if (res.statusCode == 200) {
        final data  = res.data as Map<String, dynamic>;
        final items = (data['matches'] as List<dynamic>? ??
                       data['items']   as List<dynamic>? ?? [])
            .map((e) => Match.fromJson(e as Map<String, dynamic>))
            .toList();
        return ApiSuccess(items);
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Match detail ──────────────────────────────────────────────────────────
  Future<ApiResult<Match>> getMatch(String matchId) async {
    try {
      final res = await _dio.get(ApiEndpoints.matchById(matchId));
      if (res.statusCode == 200) {
        return ApiSuccess(Match.fromJson(res.data as Map<String, dynamic>));
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Respond to interest ───────────────────────────────────────────────────
  Future<ApiResult<String>> respond({
    required String matchId,
    required bool   accept,
    String?         response,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.matchRespond(matchId),
        data: {'accept': accept, if (response != null) 'response': response},
      );
      if (res.statusCode == 200) {
        return ApiSuccess(
            accept ? 'Interest accepted. 🌙' : 'Interest respectfully declined.');
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Close / end match ─────────────────────────────────────────────────────
  Future<ApiResult<String>> closeMatch(String matchId, String reason) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.matchClose(matchId),
        data: {'reason': reason},
      );
      if (res.statusCode == 200) {
        return const ApiSuccess('Match closed respectfully.');
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Compatibility detail ──────────────────────────────────────────────────
  Future<ApiResult<Map<String, dynamic>>> getCompatibility(
      String matchId) async {
    try {
      final res = await _dio.get(ApiEndpoints.compatMatch(matchId));
      if (res.statusCode == 200) {
        return ApiSuccess(res.data as Map<String, dynamic>);
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Memory timeline ───────────────────────────────────────────────────────
  Future<ApiResult<Map<String, dynamic>>> getMemoryTimeline(
      String matchId) async {
    try {
      final res = await _dio.get(ApiEndpoints.memoryTimeline(matchId));
      if (res.statusCode == 200) {
        return ApiSuccess(res.data as Map<String, dynamic>);
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }
}

final matchRepositoryProvider = Provider<MatchRepository>(
    (ref) => MatchRepository(ref.watch(dioProvider)));
