import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/update/version_checker.dart';
import '../../core/update/models.dart';
import '../../core/update/update_repository.dart';
import '../../core/update/update_preferences.dart';
import '../../core/storage/key_value_store.dart';
import '../../core/network/api_exception.dart';
import 'update_dialog.dart';

bool _checking = false;
Future<void> checkForUpdates(
  BuildContext context,
  WidgetRef ref, {
  bool manual = false,
}) async {
  if (_checking || (!manual && !ref.read(autoUpdateProvider))) return;
  _checking = true;
  try {
    final result = await VersionChecker.check(
      ref.read(updateRepositoryProvider),
    );
    if (!context.mounted) return;
    if (!result.hasUpdate || result.latestVersion == null) {
      if (manual) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('当前版本 ${result.currentVersion} 已是最新版本')),
        );
      }
      return;
    }
    final store = ref.read(keyValueStoreProvider), info = result.latestVersion!;
    final key = 'questrace:update-reminded:${info.version}';
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!manual &&
        (!ref.read(autoUpdateProvider) ||
            now - (store.readInt(key) ?? 0) < 86400000)) {
      return;
    }
    await store.writeInt(key, now);
    if (context.mounted) {
      await UpdateDialog.show(
        context,
        MobileVersionInfo(
          version: info.version,
          apkUrl: info.apkUrl,
          forceUpdate: false,
          releaseUrl: info.releaseUrl,
          updateDescription:
              '当前版本 ${result.currentVersion}\n${info.updateDescription ?? ""}',
        ),
      );
    }
  } catch (e) {
    final message =
        e is DioException &&
            e.error is ApiException &&
            (e.error as ApiException).message.contains('GitHub')
        ? (e.error as ApiException).message
        : describeError(e);
    if (manual && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新检查失败：$message')));
    }
  } finally {
    _checking = false;
  }
}
