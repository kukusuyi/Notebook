import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/config/app_environment.dart';
import 'core/storage/key_value_store.dart';
import 'core/storage/storage_migration.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  // Copies entries written under the pre-rename keys before any repository
  // reads preferences.
  await migrateLegacyStorage(preferences);
  final appEnvironment = await AppEnvironment.load();

  runApp(
    ProviderScope(
      overrides: [
        appEnvironmentProvider.overrideWithValue(appEnvironment),
        sharedPreferencesProvider.overrideWithValue(preferences),
      ],
      child: const App(),
    ),
  );
}
