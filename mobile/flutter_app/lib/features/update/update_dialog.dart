import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/update/models.dart';
import 'update_controller.dart';

class UpdateDialog extends ConsumerWidget {
  const UpdateDialog({
    super.key,
    required this.versionInfo,
  });

  final MobileVersionInfo versionInfo;

  static Future<void> show(
    BuildContext context,
    MobileVersionInfo versionInfo,
  ) {
    return showDialog(
      context: context,
      barrierDismissible: !versionInfo.forceUpdate,
      builder: (_) => UpdateDialog(versionInfo: versionInfo),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(updateControllerProvider);

    return PopScope(
      canPop: !versionInfo.forceUpdate &&
          updateState.status != UpdateStatus.downloading,
      child: AlertDialog(
        title: const Text('发现新版本'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '最新版本: ${versionInfo.version}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (versionInfo.updateDescription != null &&
                versionInfo.updateDescription!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                versionInfo.updateDescription!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (updateState.status == UpdateStatus.downloading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: updateState.progress),
              const SizedBox(height: 8),
              Text(
                '下载中... ${(updateState.progress * 100).toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (updateState.status == UpdateStatus.error) ...[
              const SizedBox(height: 12),
              Text(
                updateState.error ?? '更新失败',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (!versionInfo.forceUpdate &&
              updateState.status != UpdateStatus.downloading)
            TextButton(
              onPressed: () {
                ref.read(updateControllerProvider.notifier).reset();
                Navigator.of(context).pop();
              },
              child: const Text('稍后再说'),
            ),
          if (updateState.status == UpdateStatus.downloading)
            const SizedBox.shrink()
          else if (updateState.status == UpdateStatus.error)
            TextButton(
              onPressed: () {
                ref.read(updateControllerProvider.notifier).downloadAndInstall(
                      versionInfo.apkUrl,
                    );
              },
              child: const Text('重试'),
            )
          else
            FilledButton(
              onPressed: () {
                ref.read(updateControllerProvider.notifier).downloadAndInstall(
                      versionInfo.apkUrl,
                    );
              },
              child: const Text('立即更新'),
            ),
        ],
      ),
    );
  }
}
