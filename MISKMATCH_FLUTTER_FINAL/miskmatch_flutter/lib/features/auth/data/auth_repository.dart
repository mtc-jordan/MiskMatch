import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miskmatch/core/api/api_client.dart';
import 'package:miskmatch/core/api/api_endpoints.dart';
import 'package:miskmatch/core/storage/secure_storage.dart';
import 'package:miskmatch/shared/models/api_response.dart';
import 'auth_models.dart';

/// Handles all auth API calls and token persistence.
/// Returns typed ApiResult — never throws.

class AuthRepository {
  AuthRepository({required this.dio, required this.storage});

  final Dio           dio;
  final SecureStorage storage;

  // ── Register ──────────────────────────────────────────────────────────────
  Future<ApiResult<String>> register(RegisterRequest req) async {
    try {
      final res = await dio.post(
        ApiEndpoints.authRegister,
        data: req.toJson(),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        final message = res.data['message'] as String? ?? 'OTP sent.';
        return ApiSuccess(message);
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Verify OTP ────────────────────────────────────────────────────────────
  Future<ApiResult<AuthTokens>> verifyOtp(OtpVerifyRequest req) async {
    try {
      final res = await dio.post(
        ApiEndpoints.authVerifyOtp,
        data: req.toJson(),
      );
      if (res.statusCode == 200) {
        final tokens = AuthTokens.fromJson(res.data as Map<String, dynamic>);
        await storage.saveTokens(
          accessToken:  tokens.accessToken,
          refreshToken: tokens.refreshToken,
          userId:       tokens.userId,
          gender:       tokens.gender,
        );
        return ApiSuccess(tokens);
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Login ─────────────────────────────────────────────────────────────────
  Future<ApiResult<AuthTokens>> login(LoginRequest req) async {
    try {
      final res = await dio.post(
        ApiEndpoints.authLogin,
        data: req.toJson(),
      );
      if (res.statusCode == 200) {
        final tokens = AuthTokens.fromJson(res.data as Map<String, dynamic>);
        await storage.saveTokens(
          accessToken:  tokens.accessToken,
          refreshToken: tokens.refreshToken,
          userId:       tokens.userId,
          gender:       tokens.gender,
        );
        return ApiSuccess(tokens);
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Resend OTP ────────────────────────────────────────────────────────────
  Future<ApiResult<String>> resendOtp(String phone) async {
    try {
      final res = await dio.post(
        ApiEndpoints.authResendOtp,
        data: {'phone': phone},
      );
      if (res.statusCode == 200) {
        return const ApiSuccess('OTP resent successfully.');
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    try {
      await dio.post(ApiEndpoints.authLogout);
    } catch (e) {
      debugPrint('AuthRepository.logout failed: $e');
    } finally {
      await storage.clearAll();
    }
  }

  // ── Delete account ─────────────────────────────────────────────────────────
  Future<ApiResult<String>> deleteAccount() async {
    try {
      final res = await dio.delete(ApiEndpoints.authDeleteAccount);
      if (res.statusCode == 200) {
        await storage.clearAll();
        return const ApiSuccess('Account deleted successfully.');
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Update niyyah ─────────────────────────────────────────────────────────
  Future<void> updateNiyyah(String niyyah) async {
    try {
      await dio.put(ApiEndpoints.authNiyyah, data: {'niyyah': niyyah});
    } catch (e) {
      debugPrint('Failed to save niyyah: $e');
    }
  }

  // ── Restore session ───────────────────────────────────────────────────────
  Future<bool> hasActiveSession() => storage.hasValidTokens();
}

// ── Provider ──────────────────────────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    dio:     ref.watch(dioProvider),
    storage: ref.watch(secureStorageProvider),
  );
});
