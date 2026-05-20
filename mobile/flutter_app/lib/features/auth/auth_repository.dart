import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../shared/models/auth_models.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});

class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  Future<AuthSession> login(LoginPayload payload) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/login',
      data: payload.toJson(),
    );

    return AuthSession.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<AuthSession> register(RegisterPayload payload) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/register',
      data: payload.toJson(),
    );

    return AuthSession.fromJson(response.data ?? <String, dynamic>{});
  }
}
