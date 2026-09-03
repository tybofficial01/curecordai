import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _tokenKey = 'access_token';
  static const _carouselKey = 'has_seen_carousel';

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  Future<bool> hasToken() async {
    final token = await _storage.read(key: _tokenKey);
    return token != null && token.isNotEmpty;
  }

  Future<void> setHasSeenCarousel(bool value) async {
    await _storage.write(key: _carouselKey, value: value.toString());
  }

  Future<bool> hasSeenCarousel() async {
    final value = await _storage.read(key: _carouselKey);
    return value == 'true';
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
