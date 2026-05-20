import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'key_value_store.dart';
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
    final normalized = value.trim();
    state = state.copyWith(apiBaseUrlOverride: normalized);

    final store = ref.read(keyValueStoreProvider);
    if (normalized.isEmpty) {
      await store.remove(StorageKeys.apiBaseUrl);
      return;
    }

    await store.writeString(StorageKeys.apiBaseUrl, normalized);
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

