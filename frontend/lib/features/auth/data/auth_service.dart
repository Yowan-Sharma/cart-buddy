import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/dio_interceptor.dart';
import '../models/user_model.dart';

class AuthService {
  AuthService(this._dio, this._storage);

  final Dio _dio;
  final FlutterSecureStorage _storage;

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    required String gender,
  }) async {
    final response = await _dio.post('users/register/', data: {
      'username': username,
      'email': email,
      'password': password,
      'first_name': firstName,
      'last_name': lastName,
      'phone': int.parse(phone),
      'gender': gender,
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await _dio.post('users/login/', data: {
      'username': username,
      'password': password,
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Uses refresh token from secure storage (set at login / register).
  Future<Map<String, dynamic>> refreshToken() async {
    final refresh = await _storage.read(key: AuthInterceptor.refreshTokenKey);
    if (refresh == null) {
      throw StateError('No refresh token in storage');
    }
    final response = await _dio.post(
      'users/refresh/',
      data: {'refresh': refresh},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<User> getMe() async {
    final response = await _dio.get('users/me/');
    return User.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<User> updateProfile(Map<String, dynamic> data) async {
    final response = await _dio.patch('users/me/', data: data);
    return User.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<Map<String, dynamic>> googleLogin(String idToken) async {
    final response = await _dio.post('users/google/', data: {'id_token': idToken});
    return Map<String, dynamic>.from(response.data as Map);
  }
}
