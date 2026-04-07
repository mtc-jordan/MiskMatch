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

  // ── Token pair ────────────────────────────────────────────────────────────
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required String userId,
  }) async {
    await Future.wait([
      saveAccessToken(accessToken),
      saveRefreshToken(refreshToken),
      saveUserId(userId),
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
