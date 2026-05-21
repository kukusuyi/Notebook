import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppEnvironment {
  const AppEnvironment({
    required this.flavor,
    required this.defaultApiBaseUrl,
    required this.defaultApiBaseUrlSource,
  });

  static const String actualConfigAssetPath = 'config/app_config.json';
  static const String exampleConfigAssetPath = 'config/app_config.example.json';
  static const String androidEmulatorApiBaseUrl = 'http://10.0.2.2:8080';
  static const String iosSimulatorApiBaseUrl = 'http://127.0.0.1:8080';

  final String flavor;
  final String defaultApiBaseUrl;
  final String defaultApiBaseUrlSource;

  factory AppEnvironment.fromFallback() {
    const flavor = String.fromEnvironment(
      'APP_FLAVOR',
      defaultValue: 'dev',
    );
    const apiBaseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: '',
    );

    final source =
        apiBaseUrl.isEmpty ? '未配置默认地址' : 'dart-define=API_BASE_URL';

    return AppEnvironment(
      flavor: flavor,
      defaultApiBaseUrl: apiBaseUrl,
      defaultApiBaseUrlSource: source,
    );
  }

  static Future<AppEnvironment> load() async {
    const flavor = String.fromEnvironment(
      'APP_FLAVOR',
      defaultValue: 'dev',
    );

    final fileConfig = await _loadConfigFromAsset(actualConfigAssetPath);
    if (fileConfig != null && fileConfig.apiBaseUrl.trim().isNotEmpty) {
      return AppEnvironment(
        flavor: fileConfig.flavor.isEmpty ? flavor : fileConfig.flavor,
        defaultApiBaseUrl: fileConfig.apiBaseUrl.trim(),
        defaultApiBaseUrlSource: actualConfigAssetPath,
      );
    }

    return _loadRuntimeFallback(flavor);
  }
}

class _AssetAppConfig {
  const _AssetAppConfig({
    required this.flavor,
    required this.apiBaseUrl,
  });

  final String flavor;
  final String apiBaseUrl;

  factory _AssetAppConfig.fromJson(Map<String, dynamic> json) {
    return _AssetAppConfig(
      flavor: (json['flavor'] ?? '').toString(),
      apiBaseUrl: (json['apiBaseUrl'] ?? '').toString(),
    );
  }
}

Future<_AssetAppConfig?> _loadConfigFromAsset(String path) async {
  try {
    final raw = await rootBundle.loadString(path);
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    return _AssetAppConfig.fromJson(decoded);
  } on FlutterError {
    return null;
  } on FormatException {
    return null;
  }
}

Future<AppEnvironment> _loadRuntimeFallback(String flavor) async {
  const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  if (apiBaseUrl.isNotEmpty) {
    return AppEnvironment(
      flavor: flavor,
      defaultApiBaseUrl: apiBaseUrl,
      defaultApiBaseUrlSource: 'dart-define=API_BASE_URL',
    );
  }

  final runtimeFallback = await _resolveRuntimeFallback();
  return AppEnvironment(
    flavor: flavor,
    defaultApiBaseUrl: runtimeFallback.apiBaseUrl,
    defaultApiBaseUrlSource: runtimeFallback.source,
  );
}

Future<_RuntimeFallback> _resolveRuntimeFallback() async {
  if (kIsWeb) {
    return const _RuntimeFallback(
      apiBaseUrl: AppEnvironment.iosSimulatorApiBaseUrl,
      source: 'Web/Simulator 默认地址',
    );
  }

  try {
    final deviceInfo = DeviceInfoPlugin();
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final info = await deviceInfo.androidInfo;
        if (!info.isPhysicalDevice) {
          return const _RuntimeFallback(
            apiBaseUrl: AppEnvironment.androidEmulatorApiBaseUrl,
            source: 'Android 模拟器默认地址',
          );
        }

        return const _RuntimeFallback(
          apiBaseUrl: '',
          source: 'Android 真机请在 config/app_config.json 或设置页填写局域网地址',
        );
      case TargetPlatform.iOS:
        final info = await deviceInfo.iosInfo;
        if (!info.isPhysicalDevice) {
          return const _RuntimeFallback(
            apiBaseUrl: AppEnvironment.iosSimulatorApiBaseUrl,
            source: 'iOS 模拟器默认地址',
          );
        }

        return const _RuntimeFallback(
          apiBaseUrl: '',
          source: 'iOS 真机请在 config/app_config.json 或设置页填写局域网地址',
        );
      default:
        break;
    }
  } catch (_) {
    // Fall through to the generic guidance below.
  }

  return const _RuntimeFallback(
    apiBaseUrl: '',
    source: '请在 config/app_config.json、dart-define 或设置页配置 API 地址',
  );
}

class _RuntimeFallback {
  const _RuntimeFallback({
    required this.apiBaseUrl,
    required this.source,
  });

  final String apiBaseUrl;
  final String source;
}

final appEnvironmentProvider = Provider<AppEnvironment>((ref) {
  return AppEnvironment.fromFallback();
});
