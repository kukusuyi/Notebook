import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:math_notebook_flutter/app/appearance.dart';
import 'package:math_notebook_flutter/app/app_theme.dart';
import 'package:math_notebook_flutter/core/storage/key_value_store.dart';
import 'package:math_notebook_flutter/core/storage/storage_keys.dart';

void main() {
  test(
      'migrates legacy color, persists appearance and preserves server settings',
      () async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.themeColorSeed: 0xff123456,
      StorageKeys.apiBaseUrl: 'http://computer:8080'
    });
    final prefs = await SharedPreferences.getInstance();
    ProviderContainer container() => ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    final first = container();
    expect(first.read(appearanceProvider).accentSeed, '#123456');
    await first
        .read(appearanceProvider.notifier)
        .update(preset: 'paper', mode: 'dark', material:'glass',font:'serif',background:'data:image/png;base64,aGVsbG8=');
    first.dispose();
    final second = container();
    expect(second.read(appearanceProvider).preset, 'paper');
    expect(second.read(appearanceProvider).mode, 'dark');
    expect(second.read(appearanceProvider).material, 'glass');
    expect(second.read(appearanceProvider).font, 'serif');
    expect(second.read(appearanceProvider).background, isNotNull);
    await second.read(appearanceProvider.notifier).reset();
    expect(second.read(appearanceProvider).accentSeed, isNull);
    expect(second.read(appearanceProvider).background, isNull);
    expect(AppearancePreferences.fromJson({'background':'https://invalid/image.png'}).background,isNull);
    expect(prefs.getString(StorageKeys.apiBaseUrl), 'http://computer:8080');
    second.dispose();
  });
  for (final preset in ['blue', 'paper', 'violet']) {
    for (final brightness in Brightness.values) {
      for (final seed in [null, Colors.black, Colors.white, Colors.yellow]) {
        test('$preset $brightness $seed contrast', () {
          final theme = buildAppTheme(
              preset: preset, brightness: brightness, seedColor: seed);
          final c = theme.colorScheme;
          for (final pair in [
            [c.primary, c.onPrimary],
            [c.onSurface, c.surface],
            [c.onSurfaceVariant, c.surface],
            [c.primary, c.primaryContainer]
          ]) {
            final a = pair[0].computeLuminance(),
                b = pair[1].computeLuminance();
            expect(((a > b ? a : b) + .05) / ((a < b ? a : b) + .05),
                greaterThanOrEqualTo(4.5));
          }
        });
      }
    }
  }
}
