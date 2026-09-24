import 'package:flutter_test/flutter_test.dart';
import 'package:questrace_flutter/core/storage/storage_keys.dart';
import 'package:questrace_flutter/core/storage/storage_migration.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('copies pre-rename keys without deleting them', () async {
    SharedPreferences.setMockInitialValues({
      'math-notebook:auth-session': '{"token":"legacy"}',
      'math-notebook:question-draft': '{"chapter":"原章节"}',
      'math-notebook:api-base-url': 'http://computer:8080',
      'math-notebook:theme-color-seed': 0xff123456,
    });
    final preferences = await SharedPreferences.getInstance();

    expect((await migrateLegacyStorage(preferences)).toSet(), {
      StorageKeys.authSession,
      StorageKeys.questionDraft,
      StorageKeys.apiBaseUrl,
      StorageKeys.themeColorSeed,
    });
    expect(preferences.getString(StorageKeys.authSession), '{"token":"legacy"}');
    expect(preferences.getString(StorageKeys.questionDraft), '{"chapter":"原章节"}');
    expect(preferences.getString(StorageKeys.apiBaseUrl), 'http://computer:8080');
    expect(preferences.getInt(StorageKeys.themeColorSeed), 0xff123456);

    // Rolling back still finds the values under their original keys.
    expect(preferences.getString('math-notebook:auth-session'), '{"token":"legacy"}');
    expect(preferences.getInt('math-notebook:theme-color-seed'), 0xff123456);
  });

  test('copies appearance preferences from the legacy appearance key', () async {
    SharedPreferences.setMockInitialValues(
        {'notebook:appearance:v1': '{"preset":"paper"}'});
    final preferences = await SharedPreferences.getInstance();

    expect(await migrateLegacyStorage(preferences),
        ['questrace:appearance:v1']);
    expect(preferences.getString('questrace:appearance:v1'), '{"preset":"paper"}');
    expect(preferences.getString('notebook:appearance:v1'), '{"preset":"paper"}');
  });

  test('never overwrites a value already stored under the current key',
      () async {
    SharedPreferences.setMockInitialValues({
      'math-notebook:api-base-url': 'http://legacy:8080',
      StorageKeys.apiBaseUrl: 'http://current:8080',
    });
    final preferences = await SharedPreferences.getInstance();

    expect(await migrateLegacyStorage(preferences), isEmpty);
    expect(preferences.getString(StorageKeys.apiBaseUrl), 'http://current:8080');
  });

  test('leaves unrelated keys untouched', () async {
    SharedPreferences.setMockInitialValues({'unrelated': 'value'});
    final preferences = await SharedPreferences.getInstance();

    expect(await migrateLegacyStorage(preferences), isEmpty);
    expect(preferences.getString('unrelated'), 'value');
  });

  test('is idempotent', () async {
    SharedPreferences.setMockInitialValues(
        {'math-notebook:auth-session': '{"token":"legacy"}'});
    final preferences = await SharedPreferences.getInstance();

    expect(await migrateLegacyStorage(preferences), [StorageKeys.authSession]);
    expect(await migrateLegacyStorage(preferences), isEmpty);
    expect(preferences.getString(StorageKeys.authSession), '{"token":"legacy"}');
  });
}
