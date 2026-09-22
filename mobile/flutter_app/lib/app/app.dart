import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'appearance.dart';
import '../core/update/version_checker.dart';
import '../features/update/update_dialog.dart';
import 'app_scroll_behavior.dart';
import 'app_router.dart';
import 'app_theme.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdate();
    });
  }

  Future<void> _checkForUpdate() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    final result = await ref.read(versionCheckerProvider.future);
    if (result.hasUpdate && result.latestVersion != null && mounted) {
      UpdateDialog.show(context, result.latestVersion!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final appearance = ref.watch(appearanceProvider);

    return MaterialApp.router(
      title: '题迹 Notebook',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(
          seedColor: appearance.accentColor, preset: appearance.preset),
      darkTheme: buildAppTheme(
          seedColor: appearance.accentColor,
          preset: appearance.preset,
          brightness: Brightness.dark),
      themeMode: appearance.themeMode,
      scrollBehavior: const AppScrollBehavior(),
      routerConfig: router,
    );
  }
}
