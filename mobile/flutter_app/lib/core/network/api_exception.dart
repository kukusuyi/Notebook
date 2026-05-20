import 'package:dio/dio.dart';

class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.code,
    this.statusCode,
  });

  final String message;
  final int? code;
  final int? statusCode;

  @override
  String toString() => message;
}

String describeError(Object error) {
  if (error is DioException && error.error is ApiException) {
    return (error.error as ApiException).message;
  }
  if (error is ApiException) {
    return error.message;
  }
  return error.toString();
}

