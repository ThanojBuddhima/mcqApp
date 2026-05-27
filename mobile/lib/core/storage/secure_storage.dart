import 'token_storage_platform.dart';
import 'token_storage_web.dart'
    if (dart.library.io) 'token_storage_io.dart';

class SecureStorage {
  static final TokenStoragePlatform _storage = createTokenStorage();

  static Future<void> saveTokens(String access, String refresh) =>
      _storage.saveTokens(access, refresh);

  static Future<String?> getAccessToken() => _storage.getAccessToken();

  static Future<String?> getRefreshToken() => _storage.getRefreshToken();

  static Future<void> clear() => _storage.clear();
}
