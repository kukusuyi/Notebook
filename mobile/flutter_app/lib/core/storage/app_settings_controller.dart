import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'key_value_store.dart';
import 'package:dio/dio.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/question_create/question_draft_controller.dart';
import 'storage_keys.dart';

class AppSettings {
  const AppSettings({
    this.apiBaseUrlOverride = '',
    this.themeColorSeed,
  });

  final String apiBaseUrlOverride;
  final int? themeColorSeed;

  AppSettings copyWith({
    String? apiBaseUrlOverride,
    int? themeColorSeed,
    bool clearThemeColorSeed = false,
  }) {
    return AppSettings(
      apiBaseUrlOverride: apiBaseUrlOverride ?? this.apiBaseUrlOverride,
      themeColorSeed:
          clearThemeColorSeed ? null : (themeColorSeed ?? this.themeColorSeed),
    );
  }
}

final appSettingsControllerProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
  AppSettingsController.new,
);

class AppSettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final store = ref.read(keyValueStoreProvider);
    final colorRaw = store.readInt(StorageKeys.themeColorSeed);
    return AppSettings(
      apiBaseUrlOverride: store.readString(StorageKeys.apiBaseUrl) ?? '',
      themeColorSeed: colorRaw,
    );
  }

  Future<void> setApiBaseUrlOverride(String value) async {
    final normalized = value.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const FormatException('请输入完整服务地址，例如 http://192.168.1.10:8080');
    }
    final probe = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5)));
    try {
      final response = await probe.get('$normalized/api/v1/system/status');
      if (response.data is! Map ||
          response.data['data']?['version'] != '2.0.0') {
        throw const FormatException('该地址不是 Questrace 2.0 服务');
      }
    } finally {
      probe.close();
    }
    if (normalized == state.apiBaseUrlOverride) return;
    await ref.read(questionDraftControllerProvider.notifier).flush();
    await ref.read(authControllerProvider.notifier).logout();
    final store = ref.read(keyValueStoreProvider);
    await store.writeString(StorageKeys.apiBaseUrl, normalized);
    state = state.copyWith(apiBaseUrlOverride: normalized);
    ref.invalidate(questionDraftControllerProvider);
  }

  Future<void> setThemeColorSeed(int? colorValue) async {
    state = state.copyWith(
      clearThemeColorSeed: colorValue == null,
      themeColorSeed: colorValue,
    );

    final store = ref.read(keyValueStoreProvider);
    if (colorValue == null) {
      await store.remove(StorageKeys.themeColorSeed);
      return;
    }

    await store.writeInt(StorageKeys.themeColorSeed, colorValue);
  }
}
