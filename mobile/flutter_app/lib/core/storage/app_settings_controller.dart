import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'key_value_store.dart';
import 'package:dio/dio.dart';
import '../network/read_retry_interceptor.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/question_create/question_draft_controller.dart';
import 'storage_keys.dart';

class AppSettings {
  const AppSettings({
    this.apiBaseUrlOverride = '',
    this.themeColorSeed,
    this.deviceId = '',
    this.serverKey = '',
  });

  final String apiBaseUrlOverride;
  final int? themeColorSeed;
  final String deviceId, serverKey;

  AppSettings copyWith({
    String? apiBaseUrlOverride,
    String? deviceId,
    String? serverKey,
    int? themeColorSeed,
    bool clearThemeColorSeed = false,
  }) {
    return AppSettings(
      deviceId: deviceId ?? this.deviceId,
      serverKey: serverKey ?? this.serverKey,
      apiBaseUrlOverride: apiBaseUrlOverride ?? this.apiBaseUrlOverride,
      themeColorSeed: clearThemeColorSeed
          ? null
          : (themeColorSeed ?? this.themeColorSeed),
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
      deviceId: store.readString('questrace:device-id') ?? '',
      serverKey: store.readString('questrace:server-key') ?? '',
    );
  }

  Future<void> setApiBaseUrlOverride(
    String value, {
    String? expectedDeviceId,
    bool reconnect = false,
  }) async {
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
    final probe = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    probe.interceptors.add(ReadRetryInterceptor(probe));
    String deviceId = '';
    final previous = state;
    try {
      final response = await probe.get('$normalized/api/v1/system/status');
      if (response.data is! Map ||
          response.data['data'] is! Map ||
          response.data['data']['version'] is! String ||
          response.data['data']['ocr_enabled'] is! bool ||
          response.data['data']['embedding_enabled'] is! bool) {
        throw const FormatException('该地址不是兼容的题迹服务');
      }
      final discovery = response.data['data']['discovery'];
      if (discovery is Map && discovery['device_id'] is String) {
        deviceId = discovery['device_id'];
      }
      if (expectedDeviceId != null && deviceId != expectedDeviceId) {
        throw const FormatException('电脑标识不一致，请重新选择电脑');
      }
    } finally {
      probe.close();
    }
    if (reconnect &&
        (state != previous || deviceId.isEmpty || deviceId != state.deviceId)) {
      return;
    }
    if (normalized == state.apiBaseUrlOverride && deviceId == state.deviceId) {
      return;
    }
    final sameDevice = deviceId.isNotEmpty && deviceId == state.deviceId;
    final sameAddress =
        normalized == state.apiBaseUrlOverride &&
        (state.deviceId.isEmpty || state.deviceId == deviceId);
    final store = ref.read(keyValueStoreProvider);
    final rememberedKey = deviceId.isEmpty
        ? null
        : store.readString('questrace:device-storage-key:$deviceId');
    final key =
        rememberedKey ??
        ((sameDevice || sameAddress)
            ? (state.serverKey.isEmpty
                  ? state.apiBaseUrlOverride
                  : state.serverKey)
            : (deviceId.isEmpty ? normalized : 'device:$deviceId'));
    await ref.read(questionDraftControllerProvider.notifier).flush();
    if (!sameDevice && !sameAddress) {
      await ref.read(authControllerProvider.notifier).logout();
    }
    if (deviceId.isNotEmpty) {
      await store.writeString('questrace:device-storage-key:$deviceId', key);
    }
    await store.writeString(StorageKeys.apiBaseUrl, normalized);
    await store.writeString('questrace:device-id', deviceId);
    await store.writeString('questrace:server-key', key);
    state = state.copyWith(
      apiBaseUrlOverride: normalized,
      deviceId: deviceId,
      serverKey: key,
    );
    // Draft/auth repositories rebuild when the stable storage key changes.
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
