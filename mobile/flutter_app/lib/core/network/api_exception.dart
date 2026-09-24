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

String describeError(Object error,
    {String fallback = '操作未完成，请稍后重试。已填写的内容会保留。'}) {
  int? status;
  String text;
  if (error is DioException) {
    status = error.response?.statusCode;
    text = error.error is ApiException
        ? (error.error as ApiException).message
        : (error.message ?? '');
    if ([
      DioExceptionType.connectionTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.sendTimeout
    ].contains(error.type)) {
      return '请求超时，请检查电脑网络或模型服务后重试。已填写的内容会保留。';
    }
    if (error.type == DioExceptionType.connectionError) {
      return '无法连接电脑，请确认电脑端正在运行、地址正确、处于同一局域网且防火墙允许连接。';
    }
  } else if (error is ApiException) {
    status = error.statusCode;
    text = error.message;
  } else {
    text = error.toString();
  }
  bool has(String pattern) =>
      RegExp(pattern, caseSensitive: false).hasMatch(text);
  if (has('quota|insufficient|balance|arrear|额度|欠费|余额') || status == 402) {
    return '模型服务额度不足或账户欠费，请在服务商控制台检查余额和计费状态。';
  }
  if (has('invalid.?api.?key|incorrect.?api.?key|authenticationerror|key 无效')) {
    return '模型 API Key 无效，请管理员检查密钥、服务开通状态和所属地域。';
  }
  if (has('rate.?limit|throttl|限流') || status == 429) {
    return '模型服务触发限流，请稍等片刻后重试。';
  }
  if (has(
      'model.*(not.found|not.exist)|invalidparameter|不受支持|does not support')) {
    return '模型名称或请求参数不受支持，请检查模型名称，并为图片识别选择视觉模型。';
  }
  if (has('access.?denied|forbidden|权限不足')) {
    return '模型服务权限不足，请检查模型授权及 API Key 所属地域。';
  }
  if (has('timeout|timed.out|deadline|超时')) {
    return '请求超时，请检查电脑网络或模型服务后重试。已填写的内容会保留。';
  }
  if (has('电脑无法连接模型服务')) return '电脑无法连接模型服务，请检查电脑的互联网连接、服务地址和代理设置。';
  if (has('socket|network|connection|dns|网络|无法连接')) {
    return '连接失败，请检查电脑服务、局域网地址和电脑的互联网连接。';
  }
  if (has('camera.*denied|photo.*denied|permission')) {
    return '没有相机或相册权限，请在系统设置中允许访问后重试。';
  }
  if (status == 401) return '登录已过期或账号密码不正确，请重新登录。';
  if (status == 403) return '当前账户没有执行此操作的权限，请联系管理员。';
  if (status == 413) return '图片过大，请裁剪或选择较小的图片。';
  if (has('未配置|尚未配置')) return '此功能尚未配置模型服务，请管理员在电脑的模型设置中完成配置；仍可手动录题。';
  if (has('decode|invalid json|no choices|格式异常')) {
    return '模型返回格式异常，请重试或更换兼容模型，也可以手动填写。';
  }
  if (status == 404) return '内容不存在或已被删除，请刷新后重试。';
  if (status != null && status >= 500) return '电脑端或模型服务暂时无法完成请求，请稍后重试并检查服务配置。';
  text = text.replaceFirst(
      RegExp(r'^(Exception|Bad state|FormatException):\s*'), '');
  if (has(r'[\u4e00-\u9fff]') &&
      text.length < 180 &&
      !has('error|exception|https?:|sql|stack|sk-')) {
    return text;
  }
  return fallback;
}
