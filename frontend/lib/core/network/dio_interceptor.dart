import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// JWT intercept: attach access token; on 401 with a Bearer token, refresh and retry once.
///
/// Mirrors RTK Query [baseQueryWithRefresh]: refresh via POST [users/refresh/], then replay the request.
/// Wire [onSessionExpired] from the app (e.g. [AuthNotifier.logout]) to avoid importing auth from here.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._dio);

  final Dio _dio;

  static const String authTokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';

  /// Called after refresh fails or no refresh token exists (clear session in app state).
  static Future<void> Function()? onSessionExpired;

  static Future<void>? _refreshLock;

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  bool _isAuthPath(String path) {
    return path.contains('users/login') ||
        path.contains('users/register') ||
        path.contains('users/refresh');
  }

  /// Only refresh when the failed request actually sent a Bearer token (expired / invalid access).
  bool _shouldAttemptRefresh(DioException err) {
    if (err.response?.statusCode != 401) return false;
    final auth = err.requestOptions.headers['Authorization'];
    if (auth is! String || !auth.startsWith('Bearer ')) return false;
    return true;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final path = options.path;
    if (!_isAuthPath(path)) {
      final token = await _storage.read(key: authTokenKey);
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (!_shouldAttemptRefresh(err)) {
      return super.onError(err, handler);
    }
    _retryAfterRefresh(err, handler);
  }

  Future<void> _retryAfterRefresh(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    try {
      await _ensureRefreshed();
      final token = await _storage.read(key: authTokenKey);
      if (token == null) {
        await _clearSessionAndNotify();
        return handler.next(err);
      }
      err.requestOptions.headers['Authorization'] = 'Bearer $token';
      final response = await _dio.fetch(err.requestOptions);
      return handler.resolve(response);
    } catch (_) {
      await _clearSessionAndNotify();
      return handler.next(err);
    }
  }

  Future<void> _ensureRefreshed() async {
    if (_refreshLock != null) {
      await _refreshLock;
      return;
    }
    _refreshLock = _performRefresh();
    try {
      await _refreshLock;
    } finally {
      _refreshLock = null;
    }
  }

  Future<void> _performRefresh() async {
    final refresh = await _storage.read(key: refreshTokenKey);
    if (refresh == null) {
      throw StateError('No refresh token');
    }
    final response = await _dio.post<Map<String, dynamic>>(
      'users/refresh/',
      data: {'refresh': refresh},
    );
    final data = response.data;
    final access = data?['access'] as String?;
    if (access == null) {
      throw StateError('No access in refresh response');
    }
    await _storage.write(key: authTokenKey, value: access);
    final newRefresh = data?['refresh'] as String?;
    if (newRefresh != null) {
      await _storage.write(key: refreshTokenKey, value: newRefresh);
    }
  }

  Future<void> _clearSessionAndNotify() async {
    await _storage.delete(key: authTokenKey);
    await _storage.delete(key: refreshTokenKey);
    final cb = onSessionExpired;
    if (cb != null) {
      await cb();
    }
  }
}
