import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

enum UpdateStatus { idle, downloading, installing, error }

class UpdateState {
  const UpdateState({
    this.status = UpdateStatus.idle,
    this.progress = 0.0,
    this.error,
  });

  final UpdateStatus status;
  final double progress;
  final String? error;

  UpdateState copyWith({
    UpdateStatus? status,
    double? progress,
    String? error,
  }) {
    return UpdateState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: error,
    );
  }
}

final updateControllerProvider =
    NotifierProvider<UpdateController, UpdateState>(UpdateController.new);

class UpdateController extends Notifier<UpdateState> {
  @override
  UpdateState build() => const UpdateState();

  Future<void> downloadAndInstall(String apkUrl) async {
    state = state.copyWith(status: UpdateStatus.downloading, progress: 0);

    try {
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        state = state.copyWith(
          status: UpdateStatus.error,
          error: '存储权限被拒绝',
        );
        return;
      }

      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/math-notebook-update.apk';

      final dio = Dio();
      await dio.download(
        apkUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            state = state.copyWith(progress: received / total);
          }
        },
      );

      state = state.copyWith(status: UpdateStatus.installing);

      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        state = state.copyWith(
          status: UpdateStatus.error,
          error: '无法打开 APK 文件: ${result.message}',
        );
      }
    } on DioException catch (e) {
      state = state.copyWith(
        status: UpdateStatus.error,
        error: '下载失败: ${e.message}',
      );
    } catch (e) {
      state = state.copyWith(
        status: UpdateStatus.error,
        error: '更新失败: $e',
      );
    }
  }

  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.requestInstallPackages.status;
      if (!status.isGranted) {
        final result = await Permission.requestInstallPackages.request();
        return result.isGranted;
      }
      return true;
    }
    return true;
  }

  void reset() {
    state = const UpdateState();
  }
}
