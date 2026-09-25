import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';
import 'models.dart';

final updateRepositoryProvider = Provider<UpdateRepository>(
  (ref) => UpdateRepository(ref.watch(apiClientProvider)),
);

class UpdateRepository {
  UpdateRepository(this._dio);
  final Dio _dio;
  Future<MobileVersionInfo> getLatestVersion() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/updates/latest',
      queryParameters: {'platform': Platform.isAndroid ? 'android' : 'ios'},
    );
    final data = response.data!;
    return MobileVersionInfo(
      version: data['version'] as String,
      apkUrl: data['download_url'] as String? ?? '',
      forceUpdate: false,
      updateDescription: data['description'] as String?,
      releaseUrl: data['release_url'] as String? ?? '',
    );
  }
}
