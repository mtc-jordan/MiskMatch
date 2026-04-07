import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miskmatch/core/api/api_client.dart';
import 'package:miskmatch/core/api/api_endpoints.dart';
import 'package:miskmatch/shared/models/api_response.dart';
import 'package:miskmatch/features/match/data/match_models.dart';

class ChatRepository {
  ChatRepository(this._dio);
  final Dio _dio;

  // ── Get paginated messages ────────────────────────────────────────────────
  Future<ApiResult<List<Message>>> getMessages(
    String matchId, {
    int    page     = 1,
    int    pageSize = 50,
    String? beforeId,
  }) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.messages(matchId),
        queryParameters: {
          'page':      page,
          'page_size': pageSize,
          if (beforeId != null) 'before_id': beforeId,
        },
      );
      if (res.statusCode == 200) {
        final data = res.data as Map<String, dynamic>;
        final msgs = (data['messages'] as List<dynamic>? ?? [])
            .map((e) => Message.fromJson(e as Map<String, dynamic>))
            .toList();
        return ApiSuccess(msgs);
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── REST send (fallback when WS unavailable) ──────────────────────────────
  Future<ApiResult<Message>> sendMessage({
    required String matchId,
    required String content,
    String          contentType = 'text',
    String?         mediaUrl,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.messages(matchId),
        data: {
          'content':      content,
          'content_type': contentType,
          if (mediaUrl != null) 'media_url': mediaUrl,
        },
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        return ApiSuccess(
            Message.fromJson(res.data as Map<String, dynamic>));
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Upload voice message ──────────────────────────────────────────────────
  Future<ApiResult<String>> uploadAudio(String matchId, File audio) async {
    try {
      final formData = FormData.fromMap({
        'audio': await MultipartFile.fromFile(
          audio.path,
          filename: 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
        ),
      });
      // Upload to profile voice endpoint for now; in prod use a dedicated
      // message-media endpoint
      final res = await _dio.post(
        '/messages/$matchId/audio',
        data:    formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      if (res.statusCode == 200) {
        return ApiSuccess(res.data['media_url'] as String);
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Mark messages as read ─────────────────────────────────────────────────
  Future<void> markRead(String matchId, List<String> messageIds) async {
    if (messageIds.isEmpty) return;
    try {
      await _dio.put(
        ApiEndpoints.messagesRead(matchId),
        data: {'message_ids': messageIds},
      );
    } catch (_) {}
  }

  // ── Report message ────────────────────────────────────────────────────────
  Future<ApiResult<String>> reportMessage({
    required String matchId,
    required String messageId,
    required String reason,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.messagesReport(matchId),
        queryParameters: {'message_id': messageId, 'reason': reason},
      );
      if (res.statusCode == 200) {
        return const ApiSuccess('Report submitted. JazakAllah Khair.');
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }
}

final chatRepositoryProvider = Provider<ChatRepository>(
    (ref) => ChatRepository(ref.watch(dioProvider)));
