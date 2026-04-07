/// MiskMatch — Environment Configuration
///
/// Supports: development, staging, production
/// Switch with --dart-define=ENVIRONMENT=production

enum Env { development, staging, production }

abstract class AppConfig {
  static const String _env = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  static Env get environment {
    switch (_env) {
      case 'production': return Env.production;
      case 'staging':    return Env.staging;
      default:           return Env.development;
    }
  }

  static bool get isDev        => environment == Env.development;
  static bool get isStaging    => environment == Env.staging;
  static bool get isProduction => environment == Env.production;

  // ── API Base URLs ─────────────────────────────────────────────────────────
  static String get apiBaseUrl {
    switch (environment) {
      case Env.production: return 'https://api.miskmatch.app/api/v1';
      case Env.staging:    return 'https://api-staging.miskmatch.app/api/v1';
      case Env.development:
      default:             return 'http://10.0.2.2:8010/api/v1';
    }
  }

  static String get wsBaseUrl {
    switch (environment) {
      case Env.production: return 'wss://api.miskmatch.app/api/v1';
      case Env.staging:    return 'wss://api-staging.miskmatch.app/api/v1';
      case Env.development:
      default:             return 'ws://10.0.2.2:8010/api/v1';
    }
  }

  // ── Timeouts ─────────────────────────────────────────────────────────────
  static const Duration connectTimeout  = Duration(seconds: 15);
  static const Duration receiveTimeout  = Duration(seconds: 30);
  static const Duration uploadTimeout   = Duration(minutes: 5);

  // ── Auth ─────────────────────────────────────────────────────────────────
  static const String accessTokenKey    = 'misk_access_token';
  static const String refreshTokenKey   = 'misk_refresh_token';
  static const String userIdKey         = 'misk_user_id';

  // ── OTP ──────────────────────────────────────────────────────────────────
  static const int otpLength        = 6;
  static const int otpResendSeconds = 60;

  // ── Media limits ──────────────────────────────────────────────────────────
  static const int maxPhotoSizeBytes       = 10 * 1024 * 1024;  // 10 MB
  static const int maxVoiceIntroSeconds    = 60;
  static const int maxGalleryPhotos        = 6;

  // ── App info ──────────────────────────────────────────────────────────────
  static const String appName    = 'MiskMatch';
  static const String appNameAr  = 'مسك ماتش';
  static const String tagline    = 'Sealed with musk.';
  static const String taglineAr  = 'ختامه مسك';
  static const String quranRef   = 'Quran 83:26';
}
