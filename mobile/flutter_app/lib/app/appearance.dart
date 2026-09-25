import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/storage/key_value_store.dart';
import '../core/storage/storage_keys.dart';
import 'theme_presets.dart';

const appearanceKey = 'questrace:appearance:v1';

class AppearancePreferences {
  const AppearancePreferences({
    this.preset = 'blue',
    this.mode = 'system',
    this.accentSeed,
    this.material = 'plain',
    this.font = 'system',
    this.background,
  });
  final String preset;
  final String mode;
  final String? accentSeed;
  final String material, font;
  final String? background;
  ThemeMode get themeMode => switch (mode) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  /// “自定义”外观所选的颜色；偏好里沿用旧的 `accentSeed` 字段名。
  Color? get customSeedColor => accentSeed == null
      ? null
      : Color(int.parse(accentSeed!.substring(1), radix: 16) | 0xff000000);

  /// 参与主题生成的种子色；只有“自定义”外观会覆盖预设配色。
  Color? get themeSeedColor =>
      preset == customThemeKey ? customSeedColor : null;
  factory AppearancePreferences.fromJson(
    Map<String, dynamic> json,
  ) => AppearancePreferences(
    material: ['plain', 'glass', 'candy'].contains(json['material'])
        ? json['material'] as String
        : 'plain',
    font: ['system', 'rounded', 'serif'].contains(json['font'])
        ? json['font'] as String
        : 'system',
    background:
        json['background'] is String &&
            (RegExp(
                  r'^file:///.*/questrace-background-[0-9]+$',
                ).hasMatch(json['background'] as String) ||
                (json['background'] as String).length < 14000050 &&
                    RegExp(
                      r'^data:image/(jpeg|png|webp);base64,[a-zA-Z0-9+/=]+$',
                    ).hasMatch(json['background']))
        ? json['background'] as String
        : null,
    preset: flutterThemeCatalog.containsKey(json['preset'])
        ? json['preset'] as String
        : 'blue',
    mode: ['system', 'light', 'dark'].contains(json['mode'])
        ? json['mode'] as String
        : 'system',
    accentSeed:
        json['accentSeed'] is String &&
            RegExp(r'^#[a-fA-F0-9]{6}$').hasMatch(json['accentSeed'] as String)
        ? json['accentSeed'] as String
        : null,
  );
  Map<String, dynamic> toJson() => {
    'version': 2,
    'preset': preset,
    'mode': mode,
    'accentSeed': accentSeed,
    'material': material,
    'font': font,
    'background': background,
  };
}

final appearanceProvider =
    NotifierProvider<AppearanceController, AppearancePreferences>(
      AppearanceController.new,
    );

class AppearanceController extends Notifier<AppearancePreferences> {
  @override
  AppearancePreferences build() {
    final store = ref.read(keyValueStoreProvider);
    try {
      final raw = store.readString(appearanceKey);
      if (raw != null) {
        final stored = jsonDecode(raw) as Map<String, dynamic>;
        var prefs = AppearancePreferences.fromJson(stored);
        final storedVersion = stored['version'] is num
            ? (stored['version'] as num).toInt()
            : 1;
        if (prefs.background?.startsWith('data:') == true) {
          Future.microtask(() async {
            try {
              if (state.background == prefs.background) {
                await update(background: prefs.background);
              }
            } catch (_) {}
          });
        }
        // 版本 1 把 accentSeed 当作强调色覆盖；从版本 2 起它是“自定义”外观色。
        if (storedVersion < 2 &&
            prefs.preset != customThemeKey &&
            prefs.accentSeed != null) {
          prefs = AppearancePreferences.fromJson({
            ...prefs.toJson(),
            'preset': customThemeKey,
          });
          Future.microtask(() async {
            try {
              if (state.accentSeed == prefs.accentSeed) {
                await update(preset: customThemeKey);
              }
            } catch (_) {}
          });
        }
        return prefs;
      }
    } catch (_) {
      /* Invalid preferences fall back without affecting credentials. */
    }
    final legacy = store.readInt(StorageKeys.themeColorSeed);
    return AppearancePreferences(
      preset: legacy == null ? 'blue' : customThemeKey,
      accentSeed: legacy == null
          ? null
          : '#${(legacy & 0xffffff).toRadixString(16).padLeft(6, '0')}',
    );
  }

  Future<void> update({
    String? preset,
    String? mode,
    String? accentSeed,
    String? material,
    String? font,
    String? background,
    bool resetBackground = false,
  }) async {
    final oldBackground = state.background;
    String? newFile;
    if (background?.startsWith('data:') == true) {
      final bytes = base64Decode(background!.split(',').last);
      if (bytes.length > 10 * 1024 * 1024) {
        throw const FormatException('请选择 10 MB 以内的图片');
      }
      final dir = await getApplicationSupportDirectory();
      await dir.create(recursive: true);
      final file = File(
        '${dir.path}/questrace-background-${DateTime.now().microsecondsSinceEpoch}',
      );
      await file.writeAsBytes(bytes, flush: true);
      background = file.uri.toString();
      newFile = background;
    }
    final next = AppearancePreferences.fromJson({
      ...state.toJson(),
      'material': material ?? state.material,
      'font': font ?? state.font,
      'background': resetBackground ? null : background ?? state.background,
      'preset': preset ?? state.preset,
      'mode': mode ?? state.mode,
      'accentSeed': accentSeed ?? state.accentSeed,
    });
    try {
      if (!await ref
          .read(keyValueStoreProvider)
          .writeString(appearanceKey, jsonEncode(next.toJson()))) {
        throw const FileSystemException('无法保存外观设置');
      }
      state = next;
    } catch (_) {
      if (newFile != null) await File.fromUri(Uri.parse(newFile)).delete();
      rethrow;
    }
    if (oldBackground != next.background &&
        oldBackground?.startsWith('file:') == true) {
      try {
        await File.fromUri(Uri.parse(oldBackground!)).delete();
      } catch (_) {}
    }
  }

  Future<void> reset() async {
    await update(resetBackground: true);
    state = const AppearancePreferences();
    await ref
        .read(keyValueStoreProvider)
        .writeString(appearanceKey, jsonEncode(state.toJson()));
  }
}
