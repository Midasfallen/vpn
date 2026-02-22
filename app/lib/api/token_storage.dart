import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _key = 'api_token';
  static const _refreshKey = 'refresh_token';
  static final FlutterSecureStorage _storage = FlutterSecureStorage();

  // Fallback для тестовой среды или при ошибках platform channel
  static String? _inMemoryToken;
  static String? _inMemoryRefreshToken;

  static Future<void> saveToken(String token) async {
    try {
      await _storage.write(key: _key, value: token);
    } catch (e) {
      // fallback
      _inMemoryToken = token;
    }
  }

  static Future<String?> readToken() async {
    try {
      final v = await _storage.read(key: _key);
      return v ?? _inMemoryToken;
    } catch (e) {
      return _inMemoryToken;
    }
  }

  static Future<void> deleteToken() async {
    try {
      await _storage.delete(key: _key);
    } catch (e) {
      _inMemoryToken = null;
    }
  }

  // --- refresh token API ---
  static Future<void> saveRefreshToken(String token) async {
    try {
      await _storage.write(key: _refreshKey, value: token);
    } catch (e) {
      _inMemoryRefreshToken = token;
    }
  }

  static Future<String?> readRefreshToken() async {
    try {
      final v = await _storage.read(key: _refreshKey);
      return v ?? _inMemoryRefreshToken;
    } catch (e) {
      return _inMemoryRefreshToken;
    }
  }

  static Future<void> deleteRefreshToken() async {
    try {
      await _storage.delete(key: _refreshKey);
    } catch (e) {
      _inMemoryRefreshToken = null;
    }
  }
}
