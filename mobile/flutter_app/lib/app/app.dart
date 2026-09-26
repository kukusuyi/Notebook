import '../core/discovery/lan_discovery.dart';
import '../core/storage/app_settings_controller.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'appearance.dart';
import '../features/update/update_check.dart';
import 'app_scroll_behavior.dart';
import 'app_router.dart';
import 'app_theme.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  Timer? _reconnectTimer;
  bool _reconnecting = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startReconnect();
  }

  void _startReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _reconnect(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startReconnect();
      _reconnect();
    } else {
      _reconnectTimer?.cancel();
    }
  }

  Future<void> _reconnect() async {
    if (_reconnecting) return;
    final id = ref.read(appSettingsControllerProvider).deviceId;
    if (id.isEmpty) return;
    _reconnecting = true;
    try {
      final computers = await LanDiscovery().scan();
      if (!mounted) return;
      for (final c in computers) {
        if (c.id == id) {
          await ref
              .read(appSettingsControllerProvider.notifier)
              .setApiBaseUrlOverride(
                c.url,
                expectedDeviceId: id,
                reconnect: true,
              );
          break;
        }
      }
    } catch (_) {
      /* The saved connection remains available for manual recovery. */
    } finally {
      _reconnecting = false;
    }
  }

  Timer? _updateTimer;
  bool _initialCheckScheduled = false;
  @override
  void dispose() {
    _updateTimer?.cancel();
    _reconnectTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final appearance = ref.watch(appearanceProvider);

    return MaterialApp.router(
      title: '题迹 Questrace',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(
        seedColor: appearance.themeSeedColor,
        preset: appearance.preset,
        material: appearance.material,
        font: appearance.font,
        hasBackground: appearance.background != null,
      ),
      darkTheme: buildAppTheme(
        seedColor: appearance.themeSeedColor,
        preset: appearance.preset,
        material: appearance.material,
        font: appearance.font,
        hasBackground: appearance.background != null,
        brightness: Brightness.dark,
      ),
      builder: (context, child) {
        _updateTimer ??= Timer.periodic(const Duration(hours: 6), (_) {
          final navigatorContext = ref
              .read(appRouterProvider)
              .routerDelegate
              .navigatorKey
              .currentContext;
          if (navigatorContext != null) checkForUpdates(navigatorContext, ref);
        });
        if (!_initialCheckScheduled) {
          _initialCheckScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final navigatorContext = ref
                .read(appRouterProvider)
                .routerDelegate
                .navigatorKey
                .currentContext;
            if (navigatorContext != null) {
              checkForUpdates(navigatorContext, ref);
            }
          });
        }
        final surfaces = Theme.of(context).extension<QuestraceSurfaces>()!;
        final background = appearance.background;
        return ColoredBox(
          color: surfaces.background,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (background != null && !MediaQuery.highContrastOf(context))
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: Opacity(
                      opacity: .25,
                      child: background.startsWith('file:')
                          ? Image.file(
                              File.fromUri(Uri.parse(background)),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            )
                          : Image.memory(
                              base64Decode(background.split(',').last),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            ),
                    ),
                  ),
                ),
              if (child != null) child,
            ],
          ),
        );
      },
      themeMode: appearance.themeMode,
      scrollBehavior: const AppScrollBehavior(),
      routerConfig: router,
    );
  }
}
