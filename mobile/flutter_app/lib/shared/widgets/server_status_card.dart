import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/network/server_capabilities.dart';
import '../../features/auth/auth_controller.dart';

final vectorJobsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((
  ref,
) async {
  ref.watch(authControllerProvider.select((s) => s.session?.token));
  final response = await ref
      .watch(apiClientProvider)
      .get('/api/v1/vector-jobs');
  if (response.data is! Map) throw const FormatException('索引状态格式不兼容');
  return Map<String, dynamic>.from(response.data as Map);
});
String statusError(Object error) {
  if (error is DioException) {
    switch (error.response?.statusCode) {
      case 401:
        return '登录已失效，请重新登录';
      case 403:
        return '当前账户没有读取权限';
      case 404:
        return '电脑版本不支持此接口，请更新电脑程序';
    }
    return '连接失败，请确认电脑在线且处于同一局域网';
  }
  return '服务响应格式不兼容，请更新电脑程序';
}

class ServerStatusCard extends ConsumerWidget {
  const ServerStatusCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(serverCapabilitiesProvider),
        jobs = ref.watch(vectorJobsProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('电脑服务与相似题索引')),
                IconButton(
                  tooltip: '刷新状态',
                  onPressed: () {
                    ref.invalidate(serverCapabilitiesProvider);
                    ref.invalidate(vectorJobsProvider);
                  },
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            status.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(statusError(e)),
              data: (data) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OCR：${data['ocr_enabled'] == true ? '可用' : '未配置'} · AI：${data['ai_enabled'] == true ? '可用' : '未配置'}',
                  ),
                  if (data['embedding_enabled'] != true)
                    const Text('相似题服务未配置，请在电脑设置中配置 Embedding。'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            jobs.when(
              loading: () => const Text('正在读取索引任务…'),
              error: (e, _) => Text('索引加载失败：${statusError(e)}'),
              data: (data) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '索引完成 ${data['done'] ?? 0} · 等待 ${data['pending'] ?? 0} · 失败 ${data['failed'] ?? 0}',
                  ),
                  if ((data['failed'] as num? ?? 0) > 0)
                    TextButton(
                      onPressed: () async {
                        try {
                          await ref
                              .read(apiClientProvider)
                              .post('/api/v1/vector-jobs/retry');
                          ref.invalidate(vectorJobsProvider);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(statusError(e))),
                            );
                          }
                        }
                      },
                      child: const Text('重试失败任务'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text('题目保存在电脑上；未配置模型也能手动录题和复习。'),
          ],
        ),
      ),
    );
  }
}
