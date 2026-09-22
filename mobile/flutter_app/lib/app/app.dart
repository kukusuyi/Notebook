import 'dart:convert';
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
          seedColor: appearance.accentColor,
          preset: appearance.preset,
          material: appearance.material,
          font: appearance.font,
          hasBackground: appearance.background != null),
      darkTheme: buildAppTheme(
          seedColor: appearance.accentColor,
          preset: appearance.preset,
          material: appearance.material,
          font: appearance.font,
          hasBackground: appearance.background != null,
          brightness: Brightness.dark),
      builder: (context, child) {
        final surfaces = Theme.of(context).extension<NotebookSurfaces>()!;
        final background = appearance.background;
        return ColoredBox(
            color: surfaces.background,
            child: Stack(fit: StackFit.expand, children: [
              if (background != null && !MediaQuery.highContrastOf(context))
                Positioned.fill(
                    child: ExcludeSemantics(
                        child: Opacity(
                            opacity: .25,
                            child: Image.memory(
                                base64Decode(background.split(',').last),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink())))),
              if (child != null) child,
            ]));
      },
      themeMode: appearance.themeMode,
      scrollBehavior: const AppScrollBehavior(),
      routerConfig: router,
    );
  }
}
