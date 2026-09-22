import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:material_color_utilities/palettes/tonal_palette.dart';
import 'theme_catalog.dart';
import 'package:material_color_utilities/hct/hct.dart';

Color parseThemeColor(String hex) =>
    Color(int.parse(hex.substring(1), radix: 16) | 0xff000000);

@immutable
class NotebookSurfaces extends ThemeExtension<NotebookSurfaces> {
  const NotebookSurfaces(
      {required this.background, required this.border, required this.muted});
  final Color background, border, muted;
  @override
  NotebookSurfaces copyWith({Color? background, Color? border, Color? muted}) =>
      NotebookSurfaces(
          background: background ?? this.background,
          border: border ?? this.border,
          muted: muted ?? this.muted);
  @override
  NotebookSurfaces lerp(covariant NotebookSurfaces? other, double t) =>
      other == null
          ? this
          : NotebookSurfaces(
              background: Color.lerp(background, other.background, t)!,
              border: Color.lerp(border, other.border, t)!,
              muted: Color.lerp(muted, other.muted, t)!);
}

ThemeData buildAppTheme(
    {Color? seedColor,
    String preset = 'blue',
    Brightness brightness = Brightness.light}) {
  final data = themeCatalog[preset] ?? themeCatalog['blue'];
  final dark = brightness == Brightness.dark;
  final colors = data[dark ? 'dark' : 'light'];
  final background = parseThemeColor(colors['background']);
  final surface = parseThemeColor(colors['surface']);
  final text = parseThemeColor(colors['text']);
  final muted = parseThemeColor(colors['muted']);
  final border = parseThemeColor(colors['border']);
  final seed = seedColor ?? parseThemeColor(data['seed']);
  final palette = TonalPalette.fromHct(Hct.fromInt(seed.toARGB32()));
  Color tone(int n) => Color(palette.get(n));
  final scheme =
      ColorScheme.fromSeed(seedColor: seed, brightness: brightness).copyWith(
    primary: tone(dark ? 80 : 40),
    onPrimary: tone(dark ? 20 : 100),
    primaryContainer: tone(dark ? 25 : 95),
    onPrimaryContainer: tone(dark ? 90 : 20),
    surface: surface,
    onSurface: text,
    onSurfaceVariant: muted,
    surfaceContainerLowest: background,
    surfaceContainerLow: surface,
    surfaceContainer: background,
    surfaceContainerHigh: background,
    surfaceContainerHighest: border,
    outline: muted,
    outlineVariant: border,
    error: dark ? const Color(0xffffb4ab) : const Color(0xffba1a1a),
    onError: dark ? const Color(0xff690005) : Colors.white,
  );
  final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamilyFallback: const [
        'PingFang SC',
        'Microsoft YaHei',
        'Noto Sans CJK SC'
      ]);
  final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12), side: BorderSide(color: border));
  return base.copyWith(
    extensions: [
      NotebookSurfaces(background: background, border: border, muted: muted)
    ],
    scaffoldBackgroundColor: background,
    textTheme: base.textTheme.copyWith(
        bodyLarge:
            base.textTheme.bodyLarge?.copyWith(fontSize: 16, height: 1.6),
        bodyMedium:
            base.textTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.5)),
    appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle:
            TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: text)),
    cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: shape,
        margin: EdgeInsets.zero),
    inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: scheme.primary, width: 2))),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)))),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)))),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48))),
    iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48))),
    navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        height: 72),
    bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)))),
    snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder()
    }),
  );
}
