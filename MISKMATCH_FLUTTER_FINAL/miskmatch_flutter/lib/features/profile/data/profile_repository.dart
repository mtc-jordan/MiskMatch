import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miskmatch/core/api/api_client.dart';
import 'package:miskmatch/core/api/api_endpoints.dart';
import 'package:miskmatch/shared/models/api_response.dart';
import 'profile_models.dart';

class ProfileRepository {
  ProfileRepository(this._dio);
  final Dio _dio;

  // ── Get my profile ────────────────────────────────────────────────────────
  Future<ApiResult<UserProfile>> getMyProfile() async {
    try {
      final res = await _dio.get(ApiEndpoints.profileMe,
        options: Options(receiveTimeout: const Duration(seconds: 3)),
      );
      if (res.statusCode == 200) {
        return ApiSuccess(UserProfile.fromJson(res.data as Map<String, dynamic>));
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Create / Update profile ───────────────────────────────────────────────
  Future<ApiResult<UserProfile>> createProfile(UserProfile profile) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.profileMe,
        data: profile.toJson(),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        return ApiSuccess(UserProfile.fromJson(res.data as Map<String, dynamic>));
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  Future<ApiResult<UserProfile>> updateProfile(UserProfile profile) async {
    try {
      final res = await _dio.put(
        ApiEndpoints.profileMe,
        data: profile.toJson(),
      );
      if (res.statusCode == 200) {
        return ApiSuccess(UserProfile.fromJson(res.data as Map<String, dynamic>));
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Get profile by ID (public view) ──────────────────────────────────────
  Future<ApiResult<UserProfile>> getProfileById(String userId) async {
    try {
      final res = await _dio.get(ApiEndpoints.profileById(userId));
      if (res.statusCode == 200) {
        return ApiSuccess(UserProfile.fromJson(res.data as Map<String, dynamic>));
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Profile completion status ─────────────────────────────────────────────
  Future<ApiResult<ProfileCompletion>> getCompletion() async {
    try {
      final res = await _dio.get(ApiEndpoints.profileCompletion,
        options: Options(receiveTimeout: const Duration(seconds: 3)),
      );
      if (res.statusCode == 200) {
        return ApiSuccess(
            ProfileCompletion.fromJson(res.data as Map<String, dynamic>));
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Upload profile photo ──────────────────────────────────────────────────
  Future<ApiResult<String>> uploadPhoto(File photo) async {
    try {
      final formData = FormData.fromMap({
        'photo': await MultipartFile.fromFile(
          photo.path,
          filename: 'profile_photo.jpg',
        ),
      });
      final res = await _dio.post(
        ApiEndpoints.profilePhoto,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );
      if (res.statusCode == 200) {
        final url = res.data['photo_url'] as String;
        return ApiSuccess(url);
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Upload voice intro ────────────────────────────────────────────────────
  Future<ApiResult<String>> uploadVoiceIntro(File audio) async {
    try {
      final formData = FormData.fromMap({
        'audio': await MultipartFile.fromFile(
          audio.path,
          filename: 'voice_intro.m4a',
        ),
      });
      final res = await _dio.post(
        ApiEndpoints.profileVoice,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      if (res.statusCode == 200) {
        final url = res.data['voice_intro_url'] as String;
        return ApiSuccess(url);
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Submit Sifr assessment ────────────────────────────────────────────────
  Future<ApiResult<Map<String, dynamic>>> submitSifr(
    Map<String, int> answers,
  ) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.profileSifr,
        data: {'answers': answers},
      );
      if (res.statusCode == 200) {
        return ApiSuccess(res.data as Map<String, dynamic>);
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Trigger AI re-embedding ───────────────────────────────────────────────
  Future<void> triggerReembed() async {
    try {
      await _dio.post(ApiEndpoints.compatEmbed);
    } catch (e) {
      debugPrint('ProfileRepository.triggerReembed failed: $e');
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────
final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(dioProvider)),
);
