import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../shared/models/file_models.dart';

final fileRepositoryProvider = Provider<FileRepository>((ref) {
  return FileRepository(ref.watch(apiClientProvider));
});

class FileRepository {
  FileRepository(this._dio);

  final Dio _dio;

  Future<UploadedImage> uploadImage(File file) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path),
      'usage': 'wrong_question',
    });

    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/files/images',
      data: formData,
    );

    return UploadedImage.fromJson(response.data ?? <String, dynamic>{});
  }
}
