import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/config/app_environment.dart';
import 'core/storage/key_value_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
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
