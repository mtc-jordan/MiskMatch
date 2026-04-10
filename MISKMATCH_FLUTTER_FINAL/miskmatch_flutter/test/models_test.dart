import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miskmatch/features/auth/data/auth_models.dart';
import 'package:miskmatch/features/wali/data/wali_models.dart';
import 'package:miskmatch/shared/models/api_response.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // AuthTokens
  // ═══════════════════════════════════════════════════════════════════════════

  group('AuthTokens', () {
    test('fromJson creates correct object with all fields', () {
      final json = {
        'access_token': 'acc123',
        'refresh_token': 'ref456',
        'user_id': 'user789',
        'token_type': 'bearer',
        'gender': 'female',
        'onboarding_completed': true,
      };

      final tokens = AuthTokens.fromJson(json);

      expect(tokens.accessToken, 'acc123');
      expect(tokens.refreshToken, 'ref456');
      expect(tokens.userId, 'user789');
      expect(tokens.tokenType, 'bearer');
      expect(tokens.gender, 'female');
      expect(tokens.onboardingCompleted, true);
    });

    test('fromJson uses defaults for missing optional fields', () {
      final json = {
        'access_token': 'acc',
        'refresh_token': 'ref',
        'user_id': 'uid',
      };

      final tokens = AuthTokens.fromJson(json);

      expect(tokens.tokenType, 'bearer');
      expect(tokens.gender, 'male');
      expect(tokens.onboardingCompleted, false);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // RegisterRequest
  // ═══════════════════════════════════════════════════════════════════════════

  group('RegisterRequest', () {
    test('toJson produces correct structure with required fields only', () {
      final req = RegisterRequest(
        phone: '+966501234567',
        password: 'secret123',
        gender: 'male',
      );

      final json = req.toJson();

      expect(json['phone'], '+966501234567');
      expect(json['password'], 'secret123');
      expect(json['gender'], 'male');
      expect(json.containsKey('email'), false);
      expect(json.containsKey('niyyah'), false);
      expect(json.containsKey('referral_code'), false);
    });

    test('toJson includes optional fields when provided', () {
      final req = RegisterRequest(
        phone: '+966501234567',
        password: 'secret123',
        gender: 'female',
        email: 'test@example.com',
        niyyah: 'marriage',
        referralCode: 'REF001',
      );

      final json = req.toJson();

      expect(json['email'], 'test@example.com');
      expect(json['niyyah'], 'marriage');
      expect(json['referral_code'], 'REF001');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // LoginRequest
  // ═══════════════════════════════════════════════════════════════════════════

  group('LoginRequest', () {
    test('toJson produces correct structure', () {
      final req = LoginRequest(phone: '+966500000000', password: 'pass');

      final json = req.toJson();

      expect(json, {'phone': '+966500000000', 'password': 'pass'});
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // OtpVerifyRequest
  // ═══════════════════════════════════════════════════════════════════════════

  group('OtpVerifyRequest', () {
    test('toJson produces correct structure', () {
      final req = OtpVerifyRequest(phone: '+966500000000', otp: '123456');

      final json = req.toJson();

      expect(json, {'phone': '+966500000000', 'otp': '123456'});
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // ApiResult / ApiResultX extension
  // ═══════════════════════════════════════════════════════════════════════════

  group('ApiResult', () {
    test('when dispatches to success callback for ApiSuccess', () {
      const ApiResult<String> result = ApiSuccess('hello');

      final output = result.when(
        success: (data) => 'got: $data',
        error: (err) => 'err: ${err.message}',
      );

      expect(output, 'got: hello');
      expect(result.isSuccess, true);
      expect(result.isError, false);
      expect(result.dataOrNull, 'hello');
      expect(result.errorOrNull, isNull);
    });

    test('when dispatches to error callback for ApiError', () {
      final ApiResult<String> result = ApiError(
        AppError(message: 'fail', type: AppErrorType.network),
      );

      final output = result.when(
        success: (data) => 'got: $data',
        error: (err) => 'err: ${err.message}',
      );

      expect(output, 'err: fail');
      expect(result.isSuccess, false);
      expect(result.isError, true);
      expect(result.dataOrNull, isNull);
      expect(result.errorOrNull, isNotNull);
      expect(result.errorOrNull!.message, 'fail');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // AppError
  // ═══════════════════════════════════════════════════════════════════════════

  group('AppError', () {
    group('fromDio', () {
      test('connectionTimeout returns network error', () {
        final dio = DioException(
          type: DioExceptionType.connectionTimeout,
          requestOptions: RequestOptions(path: '/test'),
        );

        final error = AppError.fromDio(dio);

        expect(error.type, AppErrorType.network);
        expect(error.isNetwork, true);
      });

      test('receiveTimeout returns network error', () {
        final dio = DioException(
          type: DioExceptionType.receiveTimeout,
          requestOptions: RequestOptions(path: '/test'),
        );

        final error = AppError.fromDio(dio);

        expect(error.type, AppErrorType.network);
      });

      test('connectionError returns network error', () {
        final dio = DioException(
          type: DioExceptionType.connectionError,
          requestOptions: RequestOptions(path: '/test'),
        );

        final error = AppError.fromDio(dio);

        expect(error.type, AppErrorType.network);
      });

      test('badResponse delegates to fromResponse', () {
        final dio = DioException(
          type: DioExceptionType.badResponse,
          requestOptions: RequestOptions(path: '/test'),
          response: Response(
            statusCode: 401,
            data: {'detail': 'Unauthorized'},
            requestOptions: RequestOptions(path: '/test'),
          ),
        );

        final error = AppError.fromDio(dio);

        expect(error.type, AppErrorType.auth);
        expect(error.message, 'Unauthorized');
        expect(error.statusCode, 401);
      });

      test('unknown type returns unknown error with message', () {
        final dio = DioException(
          type: DioExceptionType.cancel,
          requestOptions: RequestOptions(path: '/test'),
          message: 'Request cancelled',
        );

        final error = AppError.fromDio(dio);

        expect(error.type, AppErrorType.unknown);
        expect(error.message, 'Request cancelled');
      });
    });

    group('fromResponse', () {
      test('400 returns validation error', () {
        final error = AppError.fromResponse(400, {'detail': 'Bad input'});

        expect(error.type, AppErrorType.validation);
        expect(error.isValidation, true);
        expect(error.message, 'Bad input');
      });

      test('401 returns auth error', () {
        final error = AppError.fromResponse(401, {'message': 'Not logged in'});

        expect(error.type, AppErrorType.auth);
        expect(error.isAuth, true);
        expect(error.message, 'Not logged in');
      });

      test('403 returns auth error', () {
        final error = AppError.fromResponse(403, null);

        expect(error.type, AppErrorType.auth);
      });

      test('404 returns notFound error', () {
        final error = AppError.fromResponse(404, {'detail': 'Not found'});

        expect(error.type, AppErrorType.notFound);
        expect(error.isNotFound, true);
      });

      test('422 returns validation error', () {
        final error = AppError.fromResponse(422, {
          'detail': [
            {'msg': 'field required', 'loc': ['body', 'phone']}
          ]
        });

        expect(error.type, AppErrorType.validation);
        expect(error.message, 'field required');
      });

      test('500 returns server error', () {
        final error = AppError.fromResponse(500, null);

        expect(error.type, AppErrorType.server);
        expect(error.isServer, true);
      });

      test('502 returns server error', () {
        final error = AppError.fromResponse(502, null);

        expect(error.type, AppErrorType.server);
      });

      test('null status code returns unknown error', () {
        final error = AppError.fromResponse(null, null);

        expect(error.type, AppErrorType.unknown);
      });

      test('parses detail list with message key', () {
        final error = AppError.fromResponse(422, {
          'detail': [
            {'message': 'Phone is invalid'}
          ]
        });

        expect(error.message, 'Phone is invalid');
      });
    });

    test('toString includes type, statusCode, and message', () {
      final error = AppError(
        message: 'test error',
        statusCode: 404,
        type: AppErrorType.notFound,
      );

      expect(error.toString(), 'AppError(AppErrorType.notFound, 404): test error');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // WaliPermissions
  // ═══════════════════════════════════════════════════════════════════════════

  group('WaliPermissions', () {
    test('defaults are correct', () {
      const perms = WaliPermissions();

      expect(perms.canReadMessages, false);
      expect(perms.mustApproveMatches, true);
      expect(perms.receivesNotifications, true);
      expect(perms.canJoinCalls, true);
    });

    test('fromJson/toJson round-trip preserves values', () {
      final original = WaliPermissions(
        canReadMessages: true,
        mustApproveMatches: false,
        receivesNotifications: true,
        canJoinCalls: false,
      );

      final json = original.toJson();
      final restored = WaliPermissions.fromJson(json);

      expect(restored.canReadMessages, original.canReadMessages);
      expect(restored.mustApproveMatches, original.mustApproveMatches);
      expect(restored.receivesNotifications, original.receivesNotifications);
      expect(restored.canJoinCalls, original.canJoinCalls);
    });

    test('fromJson uses defaults for missing fields', () {
      final perms = WaliPermissions.fromJson({});

      expect(perms.canReadMessages, false);
      expect(perms.mustApproveMatches, true);
      expect(perms.receivesNotifications, true);
      expect(perms.canJoinCalls, true);
    });

    test('toJson produces correct keys', () {
      const perms = WaliPermissions();
      final json = perms.toJson();

      expect(json, {
        'can_read_messages': false,
        'must_approve_matches': true,
        'receives_notifications': true,
        'can_join_calls': true,
      });
    });

    test('copyWith overrides specified fields', () {
      const perms = WaliPermissions();
      final updated = perms.copyWith(canReadMessages: true, canJoinCalls: false);

      expect(updated.canReadMessages, true);
      expect(updated.mustApproveMatches, true);
      expect(updated.canJoinCalls, false);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // WaliSetupRequest
  // ═══════════════════════════════════════════════════════════════════════════

  group('WaliSetupRequest', () {
    test('toJson produces correct structure with nested permissions', () {
      final req = WaliSetupRequest(
        waliName: 'Abu Ahmed',
        waliPhone: '+966500000000',
        relationship: WaliRelationship.father,
        permissions: WaliPermissions(
          canReadMessages: true,
          mustApproveMatches: true,
          receivesNotifications: true,
          canJoinCalls: false,
        ),
      );

      final json = req.toJson();

      expect(json['wali_name'], 'Abu Ahmed');
      expect(json['wali_phone'], '+966500000000');
      expect(json['relationship'], 'father');
      expect(json['permissions'], isA<Map<String, dynamic>>());
      expect(json['permissions']['can_read_messages'], true);
      expect(json['permissions']['can_join_calls'], false);
    });

    test('toJson uses default permissions when not specified', () {
      final req = WaliSetupRequest(
        waliName: 'Test',
        waliPhone: '+966511111111',
        relationship: WaliRelationship.brother,
      );

      final json = req.toJson();

      expect(json['relationship'], 'brother');
      expect(json['permissions']['can_read_messages'], false);
      expect(json['permissions']['must_approve_matches'], true);
    });

    test('toJson maps all relationship types correctly', () {
      final relationships = {
        WaliRelationship.father: 'father',
        WaliRelationship.brother: 'brother',
        WaliRelationship.uncle: 'uncle',
        WaliRelationship.grandfather: 'grandfather',
        WaliRelationship.maleRelative: 'male_relative',
        WaliRelationship.imam: 'imam',
        WaliRelationship.trustedMaleGuardian: 'trusted_male_guardian',
      };

      for (final entry in relationships.entries) {
        final req = WaliSetupRequest(
          waliName: 'Test',
          waliPhone: '+966500000000',
          relationship: entry.key,
        );
        expect(req.toJson()['relationship'], entry.value);
      }
    });
  });
}
