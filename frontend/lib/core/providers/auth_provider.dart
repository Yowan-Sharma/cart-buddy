import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/auth/models/user_model.dart';
import '../network/dio_interceptor.dart';
import 'auth_services.dart';

class AuthState {
  final User? user;
  final bool isAuthenticated;

  /// Only `true` during cold start while refresh token / session is resolved.
  /// Do not set for login/register — those screens use local loading UI.
  final bool isInitializingAuth;

  AuthState({
    this.user,
    this.isAuthenticated = false,
    this.isInitializingAuth = false,
  });

  AuthState copyWith({
    User? user,
    bool? isAuthenticated,
    bool? isInitializingAuth,
  }) {
    return AuthState(
      user: user ?? this.user,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isInitializingAuth: isInitializingAuth ?? this.isInitializingAuth,
    );
  }
}

final authStateProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

class AuthNotifier extends Notifier<AuthState> {
  final _storage = const FlutterSecureStorage();

  @override
  AuthState build() {
    _checkLoginStatus();
    return AuthState(isInitializingAuth: true);
  }

  Future<void> _checkLoginStatus() async {
    try {
      final result = await ref.read(authServiceProvider).refreshToken();

      if (result.containsKey('access')) {
        await _storage.write(
          key: AuthInterceptor.authTokenKey,
          value: result['access'] as String,
        );
        if (result['refresh'] != null) {
          await _storage.write(
            key: AuthInterceptor.refreshTokenKey,
            value: result['refresh'] as String,
          );
        }
        final user = await ref.read(authServiceProvider).getMe();
        state = AuthState(
          user: user,
          isAuthenticated: true,
          isInitializingAuth: false,
        );
        return;
      }
    } catch (_) {
      await _clearTokens();
    }
    state = AuthState(isAuthenticated: false, isInitializingAuth: false);
  }

  Future<void> _clearTokens() async {
    await _storage.delete(key: AuthInterceptor.authTokenKey);
    await _storage.delete(key: AuthInterceptor.refreshTokenKey);
  }

  /// Persists access (+ optional refresh) then loads profile.
  Future<void> login(String accessToken, {String? refreshToken}) async {
    await _storage.write(key: AuthInterceptor.authTokenKey, value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: AuthInterceptor.refreshTokenKey, value: refreshToken);
    }
    try {
      final user = await ref.read(authServiceProvider).getMe();
      state = AuthState(user: user, isAuthenticated: true);
    } catch (e) {
      await _clearTokens();
      state = AuthState(isAuthenticated: false, isInitializingAuth: false);
      rethrow;
    }
  }

  Future<void> logout() async {
    await _clearTokens();
    state = AuthState(isAuthenticated: false);
  }

  Future<void> refreshUser() async {
    if (state.isAuthenticated) {
      try {
        final user = await ref.read(authServiceProvider).getMe();
        state = state.copyWith(user: user);
      } catch (_) {}
    }
  }
}
