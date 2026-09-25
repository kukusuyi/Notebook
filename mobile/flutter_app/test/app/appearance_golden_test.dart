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
import 'package:questrace_flutter/shared/widgets/appearance_card.dart';

void main() {
  const fontPath = String.fromEnvironment('QUESTRACE_UI_FONT');
  final reviewGoldenDir = Directory(
    '${Directory.current.path}/build/ui-screenshots',
  );
  setUpAll(() async {
    if (fontPath.isNotEmpty) reviewGoldenDir.createSync(recursive: true);
    const iconPath = String.fromEnvironment('QUESTRACE_ICON_FONT');
    if (iconPath.isNotEmpty) {
      await (FontLoader('MaterialIcons')
            ..addFont(File(iconPath).readAsBytes().then(ByteData.sublistView)))
          .load();
    }
    if (fontPath.isNotEmpty) {
      final bytes = ByteData.sublistView(await File(fontPath).readAsBytes());
      for (final family in ['Ahem', 'Roboto', 'PingFang SC']) {
        await (FontLoader(family)..addFont(Future.value(bytes))).load();
      }
    }
  });
  for (final preset in ['blue', 'paper', 'violet', customThemeKey]) {
    for (final brightness in Brightness.values) {
      testWidgets('appearance $preset ${brightness.name}', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(container.dispose);
        await container
            .read(appearanceProvider.notifier)
            .update(
              preset: preset,
              mode: brightness.name,
              accentSeed: preset == customThemeKey ? '#c2607f' : null,
            );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildAppTheme(
                preset: preset,
                brightness: brightness,
                seedColor: preset == customThemeKey
                    ? const Color(0xffc2607f)
                    : null,
              ),
              home: Scaffold(
                appBar: AppBar(title: const Text('我的')),
                body: const SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: AppearanceCard(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            fontPath.isEmpty
                ? 'goldens/appearance_${preset}_${brightness.name}.png'
                : Uri.file(
                    '${reviewGoldenDir.path}/flutter_${preset}_${brightness.name}.png',
                  ),
          ),
        );
      });
    }
  }
  for (final size in [
    const Size(360, 640),
    const Size(844, 390),
    const Size(1024, 768),
  ]) {
    testWidgets('appearance layout $size with large text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: const Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: AppearanceCard(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
