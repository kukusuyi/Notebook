import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../shared/models/dashboard_models.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(apiClientProvider));
});

final dashboardSnapshotProvider =
    FutureProvider.autoDispose<DashboardSnapshot>((ref) async {
  final repository = ref.watch(dashboardRepositoryProvider);

  final responses = await Future.wait<Map<String, dynamic>>([
    repository.getSummary(),
    repository.getRecentQuestions(),
    repository.getTopTags(),
  ]);

  return DashboardSnapshot(
    summary: DashboardSummary.fromJson(responses[0]),
    recentQuestions: DashboardRecentQuestions.fromJson(responses[1]).list,
    topTags: DashboardTopTags.fromJson(responses[2]),
  );
});

class DashboardRepository {
  DashboardRepository(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> getSummary() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/dashboard/summary',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getRecentQuestions({int limit = 4}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/dashboard/recent',
      queryParameters: {'limit': limit},
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getTopTags({int limit = 6}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/dashboard/tags',
      queryParameters: {'limit': limit},
    );
    return response.data ?? <String, dynamic>{};
  }
}
