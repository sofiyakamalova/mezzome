import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists JWT tokens and phone for [AuthInterceptor] / refresh.
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _phoneKey = 'user_phone';

  Future<String?> getAccessToken() => _storage.read(key: _accessTokenKey);

  Future<String?> getRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<String?> getPhone() => _storage.read(key: _phoneKey);

  Future<bool> hasTokens() async {
    final access = await getAccessToken();
    return access != null && access.isNotEmpty;
  }

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String phone,
  }) async {
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: accessToken),
      _storage.write(key: _refreshTokenKey, value: refreshToken),
      _storage.write(key: _phoneKey, value: phone),
    ]);
  }

  Future<void> updateAccessToken(String accessToken) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
  }

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _phoneKey),
    ]);
  }
}
