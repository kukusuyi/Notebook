import 'package:flutter/material.dart';
import '../../app/app_theme.dart';

/// 选择外观颜色：常用色、色相调色盘与实时深浅预览。
///
/// 只返回颜色，存储的十六进制值属于实现细节。
class AppearanceColorPicker extends StatefulWidget {
  const AppearanceColorPicker({super.key, required this.initial});
  final Color initial;

  @override
  State<AppearanceColorPicker> createState() => _AppearanceColorPickerState();
}

class _AppearanceColorPickerState extends State<AppearanceColorPicker> {
  late HSVColor color = HSVColor.fromColor(widget.initial);
  static const presets = <String, Color>{
    '海蓝': Color(0xff2563eb),
    '天青': Color(0xff0284c7),
    '湖绿': Color(0xff0891b2),
    '青竹': Color(0xff0d9488),
    '松绿': Color(0xff15803d),
    '草木': Color(0xff65a30d),
    '琥珀': Color(0xffd97706),
    '橘橙': Color(0xffea580c),
    '珊瑚': Color(0xffe45656),
    '玫红': Color(0xffe11d48),
    '蔷薇': Color(0xffdb2777),
    '兰紫': Color(0xffc026d3),
    '鸢尾': Color(0xff9333ea),
    '靛蓝': Color(0xff4f46e5),
    '栗棕': Color(0xff925c40),
    '岩灰': Color(0xff64748b),
  };

  @override
  Widget build(BuildContext context) {
    final selected = color.toColor();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: selected,
      brightness: Theme.of(context).brightness,
    );
    final palette = customPalette(selected, dark);
    final previewBackground = parseThemeColor(palette['background'] as String);
    final previewSurface = parseThemeColor(palette['surface'] as String);
    final previewText = parseThemeColor(palette['text'] as String);
    final previewMuted = parseThemeColor(palette['muted'] as String);
    final previewBorder = parseThemeColor(palette['border'] as String);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('选择外观颜色', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: previewBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: previewBorder),
              ),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: previewSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: previewBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 104,
                      height: 12,
                      decoration: BoxDecoration(
                        color: previewText,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: 168,
                      height: 8,
                      decoration: BoxDecoration(
                        color: previewMuted,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '主操作',
                            style: TextStyle(
                              color: scheme.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.palette_outlined, color: scheme.primary),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text('预览会随所选颜色更新，深浅两套外观自动匹配。'),
            const SizedBox(height: 16),
            const Text('常用颜色'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in presets.entries)
                  Semantics(
                    selected: selected.toARGB32() == entry.value.toARGB32(),
                    child: Tooltip(
                      message: entry.key,
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: entry.value,
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: () => setState(
                            () => color = HSVColor.fromColor(entry.value),
                          ),
                          child: selected.toARGB32() == entry.value.toARGB32()
                              ? Icon(
                                  Icons.check,
                                  semanticLabel: entry.key,
                                  color: entry.value.computeLuminance() > .45
                                      ? Colors.black
                                      : Colors.white,
                                )
                              : Semantics(
                                  label: entry.key,
                                  child: const SizedBox.expand(),
                                ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('拖动调色盘，微调深浅与浓淡'),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                const height = 160.0;
                void change(Offset point) => setState(
                  () => color = color
                      .withSaturation(
                        (point.dx / constraints.maxWidth).clamp(0, 1),
                      )
                      .withValue((1 - point.dy / height).clamp(0, 1)),
                );
                return GestureDetector(
                  key: const Key('color-palette'),
                  onPanDown: (event) => change(event.localPosition),
                  onPanUpdate: (event) => change(event.localPosition),
                  child: SizedBox(
                    height: height,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white,
                                  HSVColor.fromAHSV(
                                    1,
                                    color.hue,
                                    1,
                                    1,
                                  ).toColor(),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: (color.saturation * constraints.maxWidth - 10)
                              .clamp(0, constraints.maxWidth - 20),
                          top: ((1 - color.value) * height - 10).clamp(
                            0,
                            height - 20,
                          ),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: selected,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: const [
                                BoxShadow(color: Colors.black54, blurRadius: 2),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            const Text('色相'),
            Slider(
              value: color.hue,
              max: 360,
              activeColor: selected,
              semanticFormatterCallback: (v) => '色相 ${v.round()}',
              onChanged: (v) => setState(() => color = color.withHue(v)),
            ),
            ExpansionTile(
              title: const Text('精细调整'),
              tilePadding: EdgeInsets.zero,
              children: [
                const Text('浓淡'),
                Slider(
                  value: color.saturation,
                  semanticFormatterCallback: (v) => '浓淡 ${(v * 100).round()}%',
                  onChanged: (v) =>
                      setState(() => color = color.withSaturation(v)),
                ),
                const Text('明暗'),
                Slider(
                  value: color.value,
                  semanticFormatterCallback: (v) => '明暗 ${(v * 100).round()}%',
                  onChanged: (v) => setState(() => color = color.withValue(v)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, selected),
                child: const Text('应用颜色'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
