import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questrace_flutter/core/network/read_retry_interceptor.dart';

class Adapter implements HttpClientAdapter {
  Adapter(this.failures, this.type);
  int failures;
  int calls = 0;
  final DioExceptionType type;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    if (calls <= failures) {
      throw DioException(requestOptions: options, type: type);
    }
    return ResponseBody.fromString(
      '{"ok":true}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('read recovers from one connection failure', () async {
    final adapter = Adapter(1, DioExceptionType.connectionError);
    final dio = Dio()..httpClientAdapter = adapter;
    dio.interceptors.add(ReadRetryInterceptor(dio, delay: Duration.zero));
    expect((await dio.get('http://localhost/items')).data, {'ok': true});
    expect(adapter.calls, 2);
    dio.close();
  });
  for (final method in ['GET', 'POST', 'PUT', 'DELETE']) {
    test('$method retry is bounded and writes are never replayed', () async {
      final adapter = Adapter(10, DioExceptionType.connectionError);
      final dio = Dio()..httpClientAdapter = adapter;
      dio.interceptors.add(ReadRetryInterceptor(dio, delay: Duration.zero));
      await expectLater(
        dio.request('http://localhost/items', options: Options(method: method)),
        throwsA(isA<DioException>()),
      );
      expect(adapter.calls, method == 'GET' ? 2 : 1);
      dio.close();
    });
  }
  test('HTTP errors are not retried', () async {
    final adapter = Adapter(10, DioExceptionType.badResponse);
    final dio = Dio()..httpClientAdapter = adapter;
    dio.interceptors.add(ReadRetryInterceptor(dio, delay: Duration.zero));
    await expectLater(
      dio.get('http://localhost/items'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.calls, 1);
    dio.close();
  });
}
