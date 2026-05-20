import 'dart:convert';

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
  static const String fallbackApiBaseUrl = 'http://10.0.2.2:8080';

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
      defaultValue: fallbackApiBaseUrl,
    );

    final source = apiBaseUrl == fallbackApiBaseUrl
        ? '内置默认值（建议改 config/app_config.json）'
        : 'dart-define=API_BASE_URL';

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

    return AppEnvironment.fromFallback();
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

final appEnvironmentProvider = Provider<AppEnvironment>((ref) {
  return AppEnvironment.fromFallback();
});
