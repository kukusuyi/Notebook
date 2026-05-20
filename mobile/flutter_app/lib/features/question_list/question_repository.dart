import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../shared/models/common_models.dart';
import '../../shared/models/question_models.dart';

final questionRepositoryProvider = Provider<QuestionRepository>((ref) {
  return QuestionRepository(ref.watch(apiClientProvider));
});

final questionListProvider = FutureProvider.autoDispose
    .family<PageResult<QuestionListItem>, ListQuestionFilter>((ref, filter) {
  return ref.watch(questionRepositoryProvider).listQuestions(filter);
});

final questionDetailProvider =
    FutureProvider.autoDispose.family<QuestionDetail, int>((ref, questionId) {
  return ref.watch(questionRepositoryProvider).getQuestionDetail(questionId);
});

class QuestionRepository {
  QuestionRepository(this._dio);

  final Dio _dio;

  Future<PageResult<QuestionListItem>> listQuestions(
    ListQuestionFilter filter,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/wrong-questions',
      queryParameters: filter.toQueryParameters(),
    );

    return PageResult<QuestionListItem>.fromJson(
      response.data ?? <String, dynamic>{},
      QuestionListItem.fromJson,
    );
  }

  Future<QuestionDetail> getQuestionDetail(int questionId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/wrong-questions/$questionId',
    );

    return QuestionDetail.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<CreateWrongQuestionResponse> createQuestion(
    CreateWrongQuestionPayload payload,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/wrong-questions',
      data: payload.toJson(),
    );

    return CreateWrongQuestionResponse.fromJson(
      response.data ?? <String, dynamic>{},
    );
  }

  Future<void> updateQuestion(
    int questionId,
    UpdateWrongQuestionPayload payload,
  ) async {
    await _dio.put<Map<String, dynamic>>(
      '/api/v1/wrong-questions/$questionId',
      data: payload.toJson(),
    );
  }

  Future<SimilarQuestionResponse> findSimilarQuestions(
    int questionId,
    SimilarQuestionRequest payload,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/wrong-questions/$questionId/similar',
      data: payload.toJson(),
    );

    return SimilarQuestionResponse.fromJson(
      response.data ?? <String, dynamic>{},
    );
  }
}
