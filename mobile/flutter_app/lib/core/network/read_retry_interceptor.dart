import 'dart:io';
import 'package:dio/dio.dart';

/// Retry only reads, once. Never replay writes after an ambiguous disconnect.
class ReadRetryInterceptor extends Interceptor {
  ReadRetryInterceptor(
    this.dio, {
    this.delay = const Duration(milliseconds: 400),
  });
  final Dio dio;
  final Duration delay;
  static const _attempt = 'questraceReadRetry';

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final request = err.requestOptions;
    final transient =
        err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        (err.type == DioExceptionType.unknown && err.error is SocketException);
    if (!['GET', 'HEAD'].contains(request.method.toUpperCase()) ||
        !transient ||
        request.extra[_attempt] == true ||
        request.cancelToken?.isCancelled == true) {
      handler.next(err);
      return;
    }
    await Future<void>.delayed(delay);
    if (request.cancelToken?.isCancelled == true) {
      handler.next(err);
      return;
    }
    try {
      final response = await dio.fetch<dynamic>(
        request.copyWith(extra: {...request.extra, _attempt: true}),
      );
      // fetch already ran response interceptors, including envelope decoding.
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    } catch (_) {
      handler.next(err);
    }
  }
}
