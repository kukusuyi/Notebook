import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:questrace_flutter/app/appearance.dart';
import 'package:questrace_flutter/app/app_theme.dart';
import 'package:questrace_flutter/app/theme_presets.dart';
import 'package:questrace_flutter/core/storage/key_value_store.dart';
import 'package:questrace_flutter/core/storage/storage_keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory backgroundDir;
  setUp(() async {
    backgroundDir = await Directory.systemTemp.createTemp(
      'questrace-background-test',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => backgroundDir.path,
        );
  });
  tearDown(() async {
    await backgroundDir.delete(recursive: true);
  });
  test(
    'migrates legacy color, persists appearance and preserves server settings',
    () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.themeColorSeed: 0xff123456,
        StorageKeys.apiBaseUrl: 'http://computer:8080',
      });
      final prefs = await SharedPreferences.getInstance();
      ProviderContainer container() => ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      final first = container();
      // 旧版本的强调色种子现在迁移为“自定义”外观。
      expect(first.read(appearanceProvider).preset, customThemeKey);
      expect(
        first.read(appearanceProvider).customSeedColor,
        const Color(0xff123456),
      );
      await first
          .read(appearanceProvider.notifier)
          .update(
            preset: 'paper',
            mode: 'dark',
            material: 'glass',
            font: 'serif',
            background: 'data:image/png;base64,aGVsbG8=',
          );
      first.dispose();
      final second = container();
      expect(second.read(appearanceProvider).preset, 'paper');
      expect(second.read(appearanceProvider).mode, 'dark');
      expect(second.read(appearanceProvider).material, 'glass');
      expect(second.read(appearanceProvider).font, 'serif');
      expect(second.read(appearanceProvider).background, startsWith('file:'));
      expect(
        File.fromUri(
          Uri.parse(second.read(appearanceProvider).background!),
        ).readAsStringSync(),
        'hello',
      );
      expect(prefs.getString(appearanceKey), isNot(contains('base64')));
      await second.read(appearanceProvider.notifier).reset();
      expect(second.read(appearanceProvider).accentSeed, isNull);
      expect(second.read(appearanceProvider).background, isNull);
      expect(
        AppearancePreferences.fromJson({
          'background': 'https://invalid/image.png',
        }).background,
        isNull,
      );
      expect(prefs.getString(StorageKeys.apiBaseUrl), 'http://computer:8080');
      second.dispose();
    },
  );
  test(
    'migrates version 1 accent overrides to the custom appearance',
    () async {
      SharedPreferences.setMockInitialValues({
        appearanceKey: jsonEncode({
          'version': 1,
          'preset': 'blue',
          'mode': 'dark',
          'accentSeed': '#00ff00',
        }),
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      expect(container.read(appearanceProvider).preset, customThemeKey);
      expect(
        container.read(appearanceProvider).customSeedColor,
        const Color(0xff00ff00),
      );
      expect(container.read(appearanceProvider).mode, 'dark');
      // 迁移后回写为新版本，避免每次启动重新判断。
      await Future<void>.delayed(Duration.zero);
      expect(
        jsonDecode(prefs.getString(appearanceKey)!),
        containsPair('version', 2),
      );
    },
  );
  test('keeps preset palettes free of stored custom colors', () async {
    SharedPreferences.setMockInitialValues({
      appearanceKey: jsonEncode({
        'version': 2,
        'preset': 'paper',
        'mode': 'dark',
        'accentSeed': '#00ff00',
      }),
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    expect(container.read(appearanceProvider).preset, 'paper');
    expect(container.read(appearanceProvider).themeSeedColor, isNull);
  });
  test(
    'persists 10 MiB background and rejects larger input without losing it',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      final controller = container.read(appearanceProvider.notifier);
      await controller.update(
        background:
            'data:image/png;base64,${base64Encode(Uint8List(10 * 1024 * 1024))}',
      );
      final old = container.read(appearanceProvider).background!;
      expect(await File.fromUri(Uri.parse(old)).length(), 10 * 1024 * 1024);
      await expectLater(
        controller.update(
          background:
              'data:image/png;base64,${base64Encode(Uint8List(10 * 1024 * 1024 + 1))}',
        ),
        throwsFormatException,
      );
      expect(container.read(appearanceProvider).background, old);
      await controller.reset();
      expect(await File.fromUri(Uri.parse(old)).exists(), false);
    },
  );
  test(
    'custom appearance color drives the theme only for the custom preset',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      final controller = container.read(appearanceProvider.notifier);
      await controller.update(preset: customThemeKey, accentSeed: '#c2607f');
      expect(
        container.read(appearanceProvider).themeSeedColor,
        const Color(0xffc2607f),
      );
      // 切换到预设配色时不再覆盖主色，但保留所选颜色便于切回自定义。
      await controller.update(preset: 'forest');
      expect(container.read(appearanceProvider).themeSeedColor, isNull);
      expect(container.read(appearanceProvider).accentSeed, '#c2607f');
      await controller.update(preset: customThemeKey);
      expect(
        container.read(appearanceProvider).themeSeedColor,
        const Color(0xffc2607f),
      );
      expect(
        AppearancePreferences.fromJson({
          'preset': 'unknown',
          'accentSeed': '#c2607f',
        }).preset,
        'blue',
      );
    },
  );
  for (final preset in flutterThemeCatalog.keys) {
    for (final brightness in Brightness.values) {
      for (final seed in [null, Colors.black, Colors.white, Colors.yellow]) {
        test('$preset $brightness $seed contrast', () {
          final theme = buildAppTheme(
            preset: preset,
            brightness: brightness,
            seedColor: seed,
          );
          final c = theme.colorScheme;
          for (final pair in [
            [c.primary, c.onPrimary],
            [c.onSurface, c.surface],
            [c.onSurfaceVariant, c.surface],
            [c.primary, c.primaryContainer],
          ]) {
            final a = pair[0].computeLuminance(),
                b = pair[1].computeLuminance();
            expect(
              ((a > b ? a : b) + .05) / ((a < b ? a : b) + .05),
              greaterThanOrEqualTo(4.5),
            );
          }
        });
      }
    }
  }
}
