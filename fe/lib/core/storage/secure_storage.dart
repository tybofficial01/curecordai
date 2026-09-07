import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _keyAccessToken = 'access_token';
  static const _keyRefreshToken = 'refresh_token';
  static const _keyUserId = 'user_id';
  static const _keyCarouselSeen = 'carousel_seen';
  static const _keyHiveCacheKey = 'hive_cache_encryption_key';

  /// Device-specific AES-256 key used to encrypt the local HTTP/health-data cache
  /// (Hive box). Generated once per device install and persisted here - it is
  /// intentionally NOT cleared on logout, since it protects the cache box itself
  /// (which is fully wiped on logout) rather than any one user's session.
  Future<List<int>> getOrCreateCacheEncryptionKey() async {
    final existing = await _storage.read(key: _keyHiveCacheKey);
    if (existing != null) return base64Url.decode(existing);
    final key = Hive.generateSecureKey();
    await _storage.write(key: _keyHiveCacheKey, value: base64UrlEncode(key));
    return key;
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: _keyAccessToken, value: accessToken),
      _storage.write(key: _keyRefreshToken, value: refreshToken),
    ]);
  }

  Future<String?> getAccessToken() => _storage.read(key: _keyAccessToken);
  Future<String?> getRefreshToken() => _storage.read(key: _keyRefreshToken);

  Future<void> saveUserId(String userId) =>
      _storage.write(key: _keyUserId, value: userId);
  Future<String?> getUserId() => _storage.read(key: _keyUserId);

  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: _keyAccessToken),
      _storage.delete(key: _keyRefreshToken),
      _storage.delete(key: _keyUserId),
    ]);
  }

  Future<bool> hasValidSession() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<bool> hasSeenCarousel() async {
    final val = await _storage.read(key: _keyCarouselSeen);
    return val == 'true';
  }

  Future<void> markCarouselSeen() =>
      _storage.write(key: _keyCarouselSeen, value: 'true');

  Future<void> clearAll() async {
    await Future.wait([
      _storage.delete(key: _keyAccessToken),
      _storage.delete(key: _keyRefreshToken),
      _storage.delete(key: _keyUserId),
    ]);
  }
}
