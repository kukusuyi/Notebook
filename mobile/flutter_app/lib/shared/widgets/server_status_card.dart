import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';

final _serverStatusProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final status = await client.get('/api/v1/system/status');
  final jobs = await client.get('/api/v1/vector-jobs');
  return {
    ...Map<String, dynamic>.from(status.data as Map),
    'jobs': Map<String, dynamic>.from(jobs.data as Map),
  };
});

class ServerStatusCard extends ConsumerWidget {
  const ServerStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_serverStatusProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Text('电脑服务与相似题索引')),
            IconButton(
              tooltip: '刷新状态',
              onPressed: () => ref.invalidate(_serverStatusProvider),
              icon: const Icon(Icons.refresh),
            ),
          ]),
          state.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text('无法读取服务状态。请确认电脑程序正在运行、网络可达并已登录。'),
            data: (data) {
              final jobs = data['jobs'] as Map<String, dynamic>;
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'OCR：${data['ocr_enabled'] == true ? '可用' : '未配置'} · AI：${data['ai_enabled'] == true ? '可用' : '未配置'}'),
                    const SizedBox(height: 8),
                    Text(data['embedding_enabled'] == true
                        ? '索引完成 ${jobs['done'] ?? 0} · 等待 ${jobs['pending'] ?? 0} · 失败 ${jobs['failed'] ?? 0}'
                        : '相似题服务未配置，请管理员在电脑网页的设置页配置 Embedding。'),
                    const SizedBox(height: 8),
                    const Text('题目保存后在电脑后台生成索引；未配置模型也可以手动录题和查看图片。'),
                    if ((jobs['failed'] as num? ?? 0) > 0)
                      TextButton(
                        onPressed: () async {
                          try {
                            await ref
                                .read(apiClientProvider)
                                .post('/api/v1/vector-jobs/retry');
                            ref.invalidate(_serverStatusProvider);
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('重试失败，请检查电脑连接')));
                            }
                          }
                        },
                        child: const Text('重试失败任务'),
                      ),
                  ]);
            },
          ),
        ]),
      ),
    );
  }
}
