import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/app_settings_controller.dart';
import 'app_environment.dart';

final effectiveApiBaseUrlProvider = Provider<String>((ref) {
  final environment = ref.watch(appEnvironmentProvider);
  final override = ref.watch(
    appSettingsControllerProvider.select((s) => s.apiBaseUrlOverride),
  );

  if (override.isNotEmpty) {
    return override;
  }

  return environment.defaultApiBaseUrl;
});
