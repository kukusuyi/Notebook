import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import 'models.dart';

final updateRepositoryProvider = Provider<UpdateRepository>((ref) {
  final dio = ref.watch(apiClientProvider);
  return UpdateRepository(dio);
});

class UpdateRepository {
  UpdateRepository(this._dio);

  final Dio _dio;

  Future<MobileVersionInfo> getLatestVersion() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/mobile/latest-version',
    );
    return MobileVersionInfo.fromJson(response.data!);
  }
}
