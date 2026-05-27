abstract class TokenStoragePlatform {
  Future<void> saveTokens(String access, String refresh);
  Future<String?> getAccessToken();
  Future<String?> getRefreshToken();
  Future<void> clear();
}
