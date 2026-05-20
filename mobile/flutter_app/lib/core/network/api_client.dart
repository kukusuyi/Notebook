import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_environment.dart';
import '../storage/app_settings_controller.dart';
import '../storage/auth_session_repository.dart';
import 'api_exception.dart';

final apiClientProvider = Provider<Dio>((ref) {
  final environment = ref.watch(appEnvironmentProvider);
  final settings = ref.watch(appSettingsControllerProvider);
  final sessionRepository = ref.watch(authSessionRepositoryProvider);

  final baseUrl = settings.apiBaseUrlOverride.isNotEmpty
      ? settings.apiBaseUrlOverride
      : environment.defaultApiBaseUrl;

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: const {
        HttpHeaders.acceptHeader: 'application/json',
      },
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = sessionRepository.readToken();
        if (token != null && token.isNotEmpty) {
          options.headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        final payload = response.data;
        if (payload is Map<String, dynamic> && payload['code'] is int) {
          final code = payload['code'] as int;
          if (code != 0) {
            handler.reject(
              DioException(
                requestOptions: response.requestOptions,
                response: response,
                error: ApiException(
                  code: code,
                  statusCode: response.statusCode,
                  message: (payload['message'] ?? '请求失败').toString(),
                ),
              ),
            );
            return;
          }

          response.data = payload['data'];
        }
        handler.next(response);
      },
      onError: (error, handler) {
        handler.next(_normalizeDioException(error));
      },
    ),
  );

  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
      ),
    );
  }

  ref.onDispose(dio.close);
  return dio;
});

DioException _normalizeDioException(DioException error) {
  if (error.error is ApiException) {
    return error;
  }

  final payload = error.response?.data;
  if (payload is Map<String, dynamic>) {
    return DioException(
      requestOptions: error.requestOptions,
      response: error.response,
      type: error.type,
      message: (payload['message'] ?? error.message ?? '请求失败').toString(),
      error: ApiException(
        code: payload['code'] is int ? payload['code'] as int : null,
        statusCode: error.response?.statusCode,
        message: (payload['message'] ?? error.message ?? '请求失败').toString(),
      ),
      stackTrace: error.stackTrace,
    );
  }

  return DioException(
    requestOptions: error.requestOptions,
    response: error.response,
    type: error.type,
    message: error.message ?? '网络请求失败，请检查后端服务。',
    error: ApiException(
      statusCode: error.response?.statusCode,
      message: error.message ?? '网络请求失败，请检查后端服务。',
    ),
    stackTrace: error.stackTrace,
  );
}

