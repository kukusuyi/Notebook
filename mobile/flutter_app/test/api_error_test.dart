import 'package:flutter_test/flutter_test.dart';
import 'package:math_notebook_flutter/core/network/api_exception.dart';
import 'package:dio/dio.dart';

void main() {
  test('provider diagnostics never expose credentials', () {
    expect(describeError(Exception('InvalidApiKey sk-secret')),
        contains('API Key'));
    expect(describeError(Exception('insufficient quota sk-secret')),
        contains('额度'));
    expect(describeError(Exception('SQL error sk-secret')),
        isNot(contains('sk-secret')));
  });
  test('transport failures differ from account authorization', () {
    expect(
        describeError(DioException(
            requestOptions: RequestOptions(path: '/'),
            type: DioExceptionType.connectionError)),
        contains('无法连接电脑'));
    expect(
        describeError(
            const ApiException(message: 'unauthorized', statusCode: 401)),
        contains('登录'));
    expect(
        describeError(const ApiException(message: 'denied', statusCode: 403)),
        contains('账户'));
  });
}
