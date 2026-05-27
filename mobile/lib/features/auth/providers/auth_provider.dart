import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';

class AuthState {
  final Map<String, dynamic>? user;
  final bool isLoading;
  final String? error;

  const AuthState({this.user, this.isLoading = false, this.error});

  bool get isAuthenticated => user != null;

  AuthState copyWith({Map<String, dynamic>? user, bool? isLoading, String? error}) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._dio) : super(const AuthState()) {
    _loadUser();
  }

  final Dio _dio;

  Future<void> _loadUser() async {
    final token = await SecureStorage.getAccessToken();
    if (token == null) return;
    try {
      final res = await _dio.get('/auth/me');
      state = AuthState(user: Map<String, dynamic>.from(res.data));
    } catch (_) {
      await SecureStorage.clear();
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _dio.post('/auth/login', data: {'email': email, 'password': password});
      await SecureStorage.saveTokens(res.data['access_token'], res.data['refresh_token']);
      final userRes = await _dio.get('/auth/me');
      state = AuthState(user: Map<String, dynamic>.from(userRes.data));
      return true;
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: e.response?.data?['detail']?.toString() ?? 'Login failed');
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String grade,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _dio.post('/auth/register', data: {
        'name': name,
        'grade': grade,
        'email': email,
        'password': password,
        'confirm_password': confirmPassword,
      });
      return login(email, password);
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'];
      String message = 'Registration failed';
      if (detail is String) {
        message = detail;
      } else if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map) {
          message = first['msg']?.toString() ?? message;
          if (message.startsWith('Value error, ')) {
            message = message.substring(13);
          }
        }
      }
      state = state.copyWith(isLoading: false, error: message);
      return false;
    }
  }

  Future<void> logout() async {
    await SecureStorage.clear();
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(dioProvider));
});
