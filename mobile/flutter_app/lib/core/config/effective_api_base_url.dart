import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/app_settings_controller.dart';
import 'app_environment.dart';

final effectiveApiBaseUrlProvider = Provider<String>((ref) {
  final environment = ref.watch(appEnvironmentProvider);
  final settings = ref.watch(appSettingsControllerProvider);

  if (settings.apiBaseUrlOverride.isNotEmpty) {
    return settings.apiBaseUrlOverride;
  }

  return environment.defaultApiBaseUrl;
});

