import 'package:web/web.dart' as web;

import 'token_storage_platform.dart';

class WebTokenStorage implements TokenStoragePlatform {
  static const _accessKey = 'mcq_access_token';
  static const _refreshKey = 'mcq_refresh_token';

  @override
  Future<void> saveTokens(String access, String refresh) async {
    web.window.localStorage.setItem(_accessKey, access);
    web.window.localStorage.setItem(_refreshKey, refresh);
  }

  @override
  Future<String?> getAccessToken() async => web.window.localStorage.getItem(_accessKey);

  @override
  Future<String?> getRefreshToken() async => web.window.localStorage.getItem(_refreshKey);

  @override
  Future<void> clear() async {
    web.window.localStorage.removeItem(_accessKey);
    web.window.localStorage.removeItem(_refreshKey);
  }
}

TokenStoragePlatform createTokenStorage() => WebTokenStorage();
