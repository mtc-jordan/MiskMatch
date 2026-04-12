import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/env.dart';

/// Wraps flutter_secure_storage with typed accessors for MiskMatch tokens.
/// Uses AES encryption on Android, Keychain on iOS.

class SecureStorage {
  SecureStorage(this._storage);

  final FlutterSecureStorage _storage;

  // ── Tokens ────────────────────────────────────────────────────────────────
  Future<void> saveAccessToken(String token) =>
      _storage.write(key: AppConfig.accessTokenKey, value: token);

  Future<String?> getAccessToken() =>
      _storage.read(key: AppConfig.accessTokenKey);

  Future<void> saveRefreshToken(String token) =>
      _storage.write(key: AppConfig.refreshTokenKey, value: token);

  Future<String?> getRefreshToken() =>
      _storage.read(key: AppConfig.refreshTokenKey);

  Future<void> saveUserId(String userId) =>
      _storage.write(key: AppConfig.userIdKey, value: userId);

  Future<String?> getUserId() =>
      _storage.read(key: AppConfig.userIdKey);

  Future<void> saveGender(String gender) =>
      _storage.write(key: AppConfig.genderKey, value: gender);

  Future<String?> getGender() =>
      _storage.read(key: AppConfig.genderKey);

  // ── Locale preference ─────────────────────────────────────────────────────
  Future<void> saveLocale(String localeTag) =>
      _storage.write(key: AppConfig.localeKey, value: localeTag);

  Future<String?> getLocale() =>
      _storage.read(key: AppConfig.localeKey);

  // ── Token pair ────────────────────────────────────────────────────────────
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required String userId,
    String? gender,
  }) async {
    await Future.wait([
      saveAccessToken(accessToken),
      saveRefreshToken(refreshToken),
      saveUserId(userId),
      if (gender != null) saveGender(gender),
    ]);
  }

  Future<bool> hasValidTokens() async {
    final access  = await getAccessToken();
    final refresh = await getRefreshToken();
    return access != null && refresh != null;
  }

  // ── Clear all auth data on logout ─────────────────────────────────────────
  Future<void> clearAll() async {
    await Future.wait([
      _storage.delete(key: AppConfig.accessTokenKey),
      _storage.delete(key: AppConfig.refreshTokenKey),
      _storage.delete(key: AppConfig.userIdKey),
      _storage.delete(key: AppConfig.genderKey),
    ]);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final secureStorageProvider = Provider<SecureStorage>((ref) {
  return SecureStorage(
    const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    ),
  );
});
