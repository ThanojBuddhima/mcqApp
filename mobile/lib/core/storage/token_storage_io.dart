import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'token_storage_platform.dart';

class MobileTokenStorage implements TokenStoragePlatform {
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const _secure = FlutterSecureStorage();

  @override
  Future<void> saveTokens(String access, String refresh) async {
    await _secure.write(key: _accessKey, value: access);
    await _secure.write(key: _refreshKey, value: refresh);
  }

  @override
  Future<String?> getAccessToken() => _secure.read(key: _accessKey);

  @override
  Future<String?> getRefreshToken() => _secure.read(key: _refreshKey);

  @override
  Future<void> clear() async {
    await _secure.delete(key: _accessKey);
    await _secure.delete(key: _refreshKey);
  }
}

TokenStoragePlatform createTokenStorage() => MobileTokenStorage();
