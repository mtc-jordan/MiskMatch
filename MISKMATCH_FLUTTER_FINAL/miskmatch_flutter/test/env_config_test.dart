import 'package:flutter_test/flutter_test.dart';
import 'package:miskmatch/core/config/env.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // Environment detection
  // ═══════════════════════════════════════════════════════════════════════════

  group('AppConfig environment', () {
    test('defaults to development', () {
      // Without --dart-define=ENVIRONMENT, should be development
      expect(AppConfig.environment, Env.development);
      expect(AppConfig.isDev, true);
      expect(AppConfig.isStaging, false);
      expect(AppConfig.isProduction, false);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // API URLs
  // ═══════════════════════════════════════════════════════════════════════════

  group('AppConfig API URLs', () {
    test('dev apiBaseUrl uses http scheme', () {
      // In test runner, ENVIRONMENT is not set → development
      expect(AppConfig.apiBaseUrl, startsWith('http://'));
      expect(AppConfig.apiBaseUrl, endsWith('/api/v1'));
    });

    test('dev wsBaseUrl uses ws scheme', () {
      expect(AppConfig.wsBaseUrl, startsWith('ws://'));
      expect(AppConfig.wsBaseUrl, endsWith('/api/v1'));
    });

    test('dev URLs do not use https/wss', () {
      // Dev should never accidentally use secure URLs (no certs locally)
      expect(AppConfig.apiBaseUrl, isNot(startsWith('https://')));
      expect(AppConfig.wsBaseUrl, isNot(startsWith('wss://')));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Timeouts
  // ═══════════════════════════════════════════════════════════════════════════

  group('AppConfig timeouts', () {
    test('connectTimeout is 15 seconds', () {
      expect(AppConfig.connectTimeout, const Duration(seconds: 15));
    });

    test('receiveTimeout is 30 seconds', () {
      expect(AppConfig.receiveTimeout, const Duration(seconds: 30));
    });

    test('uploadTimeout is 5 minutes', () {
      expect(AppConfig.uploadTimeout, const Duration(minutes: 5));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Auth key constants
  // ═══════════════════════════════════════════════════════════════════════════

  group('AppConfig storage keys', () {
    test('keys are non-empty and prefixed', () {
      expect(AppConfig.accessTokenKey, isNotEmpty);
      expect(AppConfig.refreshTokenKey, isNotEmpty);
      expect(AppConfig.userIdKey, isNotEmpty);
      expect(AppConfig.genderKey, isNotEmpty);

      // All should have consistent prefix
      expect(AppConfig.accessTokenKey, startsWith('misk_'));
      expect(AppConfig.refreshTokenKey, startsWith('misk_'));
      expect(AppConfig.userIdKey, startsWith('misk_'));
      expect(AppConfig.genderKey, startsWith('misk_'));
    });

    test('keys are distinct', () {
      final keys = {
        AppConfig.accessTokenKey,
        AppConfig.refreshTokenKey,
        AppConfig.userIdKey,
        AppConfig.genderKey,
      };
      expect(keys.length, 4, reason: 'All storage keys must be unique');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Media limits
  // ═══════════════════════════════════════════════════════════════════════════

  group('AppConfig media limits', () {
    test('photo size limit is 10 MB', () {
      expect(AppConfig.maxPhotoSizeBytes, 10 * 1024 * 1024);
    });

    test('voice intro max is 60 seconds', () {
      expect(AppConfig.maxVoiceIntroSeconds, 60);
    });

    test('gallery photo limit is reasonable', () {
      expect(AppConfig.maxGalleryPhotos, greaterThanOrEqualTo(1));
      expect(AppConfig.maxGalleryPhotos, lessThanOrEqualTo(20));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // OTP config
  // ═══════════════════════════════════════════════════════════════════════════

  group('AppConfig OTP', () {
    test('OTP length is 6', () {
      expect(AppConfig.otpLength, 6);
    });

    test('OTP resend cooldown is positive', () {
      expect(AppConfig.otpResendSeconds, greaterThan(0));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // App metadata
  // ═══════════════════════════════════════════════════════════════════════════

  group('AppConfig app info', () {
    test('app names are non-empty', () {
      expect(AppConfig.appName, isNotEmpty);
      expect(AppConfig.appNameAr, isNotEmpty);
    });

    test('taglines are non-empty', () {
      expect(AppConfig.tagline, isNotEmpty);
      expect(AppConfig.taglineAr, isNotEmpty);
    });

    test('quran reference is present', () {
      expect(AppConfig.quranRef, contains('83:26'));
    });
  });
}
