import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/storage/key_value_store.dart';
import '../core/storage/storage_keys.dart';

const appearanceKey = 'questrace:appearance:v1';

class AppearancePreferences {
  const AppearancePreferences(
      {this.preset = 'blue',
      this.mode = 'system',
      this.accentSeed,
      this.material = 'plain',
      this.font = 'system',
      this.background});
  final String preset;
  final String mode;
  final String? accentSeed;
  final String material, font;
  final String? background;
  ThemeMode get themeMode => switch (mode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system
      };
  Color? get accentColor => accentSeed == null
      ? null
      : Color(int.parse(accentSeed!.substring(1), radix: 16) | 0xff000000);
  factory AppearancePreferences.fromJson(Map<String, dynamic> json) =>
      AppearancePreferences(
        material: ['plain', 'glass', 'candy'].contains(json['material'])
            ? json['material'] as String
            : 'plain',
        font: ['system', 'rounded', 'serif'].contains(json['font'])
            ? json['font'] as String
            : 'system',
        background: json['background'] is String &&
                (json['background'] as String).length < 2800000 &&
                RegExp(r'^data:image/(jpeg|png|webp);base64,[a-zA-Z0-9+/=]+$')
                    .hasMatch(json['background'])
            ? json['background'] as String
            : null,
        preset: ['blue', 'paper', 'violet'].contains(json['preset'])
            ? json['preset'] as String
            : 'blue',
        mode: ['system', 'light', 'dark'].contains(json['mode'])
            ? json['mode'] as String
            : 'system',
        accentSeed: json['accentSeed'] is String &&
                RegExp(r'^#[a-fA-F0-9]{6}$')
                    .hasMatch(json['accentSeed'] as String)
            ? json['accentSeed'] as String
            : null,
      );
  Map<String, dynamic> toJson() => {
        'version': 1,
        'preset': preset,
        'mode': mode,
        'accentSeed': accentSeed,
        'material': material,
        'font': font,
        'background': background
      };
}

final appearanceProvider =
    NotifierProvider<AppearanceController, AppearancePreferences>(
        AppearanceController.new);

class AppearanceController extends Notifier<AppearancePreferences> {
  @override
  AppearancePreferences build() {
    final store = ref.read(keyValueStoreProvider);
    try {
      final raw = store.readString(appearanceKey);
      if (raw != null) {
        return AppearancePreferences.fromJson(
            jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {
      /* Invalid preferences fall back without affecting credentials. */
    }
    final legacy = store.readInt(StorageKeys.themeColorSeed);
    return AppearancePreferences(
        accentSeed: legacy == null
            ? null
            : '#${(legacy & 0xffffff).toRadixString(16).padLeft(6, '0')}');
  }

  Future<void> update(
      {String? preset,
      String? mode,
      String? accentSeed,
      String? material,
      String? font,
      String? background,
      bool resetBackground = false,
      bool resetAccent = false}) async {
    state = AppearancePreferences.fromJson({
      ...state.toJson(),
      'material': material ?? state.material,
      'font': font ?? state.font,
      'background': resetBackground ? null : background ?? state.background,
      'preset': preset ?? state.preset,
      'mode': mode ?? state.mode,
      'accentSeed': resetAccent ? null : accentSeed ?? state.accentSeed
    });
    await ref
        .read(keyValueStoreProvider)
        .writeString(appearanceKey, jsonEncode(state.toJson()));
  }

  Future<void> reset() async {
    state = const AppearancePreferences();
    await ref
        .read(keyValueStoreProvider)
        .writeString(appearanceKey, jsonEncode(state.toJson()));
  }
}
