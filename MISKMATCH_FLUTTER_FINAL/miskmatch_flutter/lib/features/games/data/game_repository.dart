import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miskmatch/core/api/api_client.dart';
import 'package:miskmatch/core/api/api_endpoints.dart';
import 'package:miskmatch/shared/models/api_response.dart';
import 'game_models.dart';

class GameRepository {
  GameRepository(this._dio);
  final Dio _dio;

  // ── Game catalogue ────────────────────────────────────────────────────────
  Future<ApiResult<GameCatalogue>> getCatalogue(String matchId) async {
    try {
      final res = await _dio.get(ApiEndpoints.gameCatalogue(matchId));
      if (res.statusCode == 200) {
        return ApiSuccess(
            GameCatalogue.fromJson(res.data as Map<String, dynamic>));
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Start a game ──────────────────────────────────────────────────────────
  Future<ApiResult<GameState>> startGame(
      String matchId, String gameType) async {
    try {
      final res = await _dio.post(
          ApiEndpoints.gameStart(matchId, gameType));
      if (res.statusCode == 200 || res.statusCode == 201) {
        return ApiSuccess(
            GameState.fromJson(res.data as Map<String, dynamic>));
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Get game state ────────────────────────────────────────────────────────
  Future<ApiResult<GameState>> getGameState(
      String matchId, String gameType) async {
    try {
      final res = await _dio.get(ApiEndpoints.gameState(matchId, gameType));
      if (res.statusCode == 200) {
        return ApiSuccess(
            GameState.fromJson(res.data as Map<String, dynamic>));
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Submit async turn ─────────────────────────────────────────────────────
  Future<ApiResult<TurnResult>> submitTurn({
    required String matchId,
    required String gameType,
    required String answer,
    Map<String, dynamic>? answerData,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.gameTurn(matchId, gameType),
        data: {
          'answer':      answer,
          if (answerData != null) 'answer_data': answerData,
        },
      );
      if (res.statusCode == 200) {
        return ApiSuccess(
            TurnResult.fromJson(res.data as Map<String, dynamic>));
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Submit real-time answer ───────────────────────────────────────────────
  Future<ApiResult<TurnResult>> submitRealtime({
    required String matchId,
    required String gameType,
    required String questionId,
    required String answer,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.gameRealtime(matchId, gameType),
        data: {'question_id': questionId, 'answer': answer},
      );
      if (res.statusCode == 200) {
        return ApiSuccess(
            TurnResult.fromJson(res.data as Map<String, dynamic>));
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Time Capsule ──────────────────────────────────────────────────────────
  Future<ApiResult<Map<String, dynamic>>> sealCapsule(String matchId) async {
    try {
      final res = await _dio.post(ApiEndpoints.timeCapsuleSeal(matchId));
      if (res.statusCode == 200) {
        return ApiSuccess(res.data as Map<String, dynamic>);
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  Future<ApiResult<Map<String, dynamic>>> openCapsule(String matchId) async {
    try {
      final res = await _dio.post(ApiEndpoints.timeCapsuleOpen(matchId));
      if (res.statusCode == 200) {
        return ApiSuccess(res.data as Map<String, dynamic>);
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Match Memory Timeline ─────────────────────────────────────────────────
  Future<ApiResult<MemoryTimeline>> getMemoryTimeline(
      String matchId) async {
    try {
      final res = await _dio.get(ApiEndpoints.memoryTimeline(matchId));
      if (res.statusCode == 200) {
        return ApiSuccess(
            MemoryTimeline.fromJson(res.data as Map<String, dynamic>));
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }
}

final gameRepositoryProvider = Provider<GameRepository>(
    (ref) => GameRepository(ref.watch(dioProvider)));
