import 'package:math_notebook_flutter/core/network/api_exception.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/appearance.dart';
import '../../app/app_theme.dart';
import '../../app/theme_catalog.dart';

class AppearanceCard extends ConsumerWidget {
  const AppearanceCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appearanceProvider);
    final controller = ref.read(appearanceProvider.notifier);
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('外观', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('选择适合你的阅读空间。'),
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final entry in themeCatalog.entries)
                  ChoiceChip(
                      label: Text(entry.value['label']),
                      avatar: CircleAvatar(
                          backgroundColor: parseThemeColor(entry.value['seed']),
                          radius: 8),
                      selected: prefs.preset == entry.key,
                      onSelected: (_) => controller.update(preset: entry.key)),
              ]),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                  value: prefs.mode,
                  decoration: const InputDecoration(labelText: '显示模式'),
                  items: const [
                    DropdownMenuItem(value: 'system', child: Text('跟随系统')),
                    DropdownMenuItem(value: 'light', child: Text('浅色')),
                    DropdownMenuItem(value: 'dark', child: Text('深色'))
                  ],
                  onChanged: (value) => controller.update(mode: value)),
              const SizedBox(height: 12),
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: Theme.of(context).colorScheme.primary),
                  title: const Text('自选强调色'),
                  subtitle: Text(prefs.accentSeed ?? '使用主题颜色'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _chooseColor(context, ref)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                  value: prefs.material,
                  decoration: const InputDecoration(labelText: '界面质感'),
                  items: const [
                    DropdownMenuItem(value: 'plain', child: Text('简洁纸面')),
                    DropdownMenuItem(value: 'glass', child: Text('流光玻璃')),
                    DropdownMenuItem(value: 'candy', child: Text('柔软糖果'))
                  ],
                  onChanged: (value) => controller.update(material: value)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                  value: prefs.font,
                  decoration: const InputDecoration(labelText: '字体风格'),
                  items: const [
                    DropdownMenuItem(value: 'system', child: Text('现代黑体')),
                    DropdownMenuItem(value: 'rounded', child: Text('圆润人文')),
                    DropdownMenuItem(value: 'serif', child: Text('书卷宋体'))
                  ],
                  onChanged: (value) => controller.update(font: value)),
              const SizedBox(height: 12),
              const Text('字体使用本机可用字体，缺少时自动回退。背景只保存在此设备。'),
              Wrap(spacing: 8, children: [
                OutlinedButton.icon(
                    onPressed: () => _chooseBackground(context, ref),
                    icon: const Icon(Icons.wallpaper),
                    label: const Text('选择背景图片')),
                if (prefs.background != null)
                  TextButton(
                      onPressed: () => controller.update(resetBackground: true),
                      child: const Text('移除背景'))
              ]),
              Wrap(spacing: 8, children: [
                TextButton(
                    onPressed: () => controller.update(resetAccent: true),
                    child: const Text('使用主题颜色')),
                TextButton(
                    onPressed: controller.reset, child: const Text('恢复默认外观'))
              ]),
            ])));
  }

  Future<void> _chooseBackground(BuildContext context, WidgetRef ref) async {
    try {
      final image = await ImagePicker().pickImage(
          source: ImageSource.gallery, maxWidth: 1920, imageQuality: 85);
      if (image == null || !context.mounted) return;
      final bytes = await image.readAsBytes();
      if (bytes.length > 2 * 1024 * 1024) throw Exception('请选择 2 MB 以内的背景图片');
      final mime = bytes.length > 8 && bytes[0] == 137 && bytes[1] == 80
          ? 'png'
          : bytes.length > 2 && bytes[0] == 255 && bytes[1] == 216
              ? 'jpeg'
              : bytes.length > 12 &&
                      ascii.decode(bytes.sublist(8, 12), allowInvalid: true) ==
                          'WEBP'
                  ? 'webp'
                  : null;
      if (mime == null) throw Exception('请选择 JPG、PNG 或 WebP 图片');
      if (!context.mounted) return;
      await ref
          .read(appearanceProvider.notifier)
          .update(background: 'data:image/$mime;base64,${base64Encode(bytes)}');
    } catch (error) {
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('背景设置失败：${describeError(error)}')));
    }
  }

  Future<void> _chooseColor(BuildContext context, WidgetRef ref) async {
    final initial = ref.read(appearanceProvider).accentColor ??
        Theme.of(context).colorScheme.primary;
    var hsv = HSVColor.fromColor(initial);
    final input = TextEditingController(
        text:
            '#${(initial.toARGB32() & 0xffffff).toRadixString(16).padLeft(6, '0')}');
    String? error;
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (sheetContext) =>
            StatefulBuilder(builder: (context, setState) {
              void change(HSVColor color) {
                setState(() {
                  hsv = color;
                  input.text =
                      '#${(color.toColor().toARGB32() & 0xffffff).toRadixString(16).padLeft(6, '0')}';
                  error = null;
                });
              }

              return Padding(
                  padding: EdgeInsets.fromLTRB(
                      24, 24, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
                  child: SingleChildScrollView(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('选择强调色',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 12),
                        const Text('文字与背景会自动调整，保持清晰可读。'),
                        const SizedBox(height: 16),
                        TextField(
                            controller: input,
                            decoration: InputDecoration(
                                labelText: '颜色值',
                                hintText: '#2563EB',
                                errorText: error),
                            onChanged: (value) {
                              if (RegExp(r'^#[a-fA-F0-9]{6}$').hasMatch(value))
                                setState(() => hsv =
                                    HSVColor.fromColor(parseThemeColor(value)));
                            }),
                        const SizedBox(height: 16),
                        const Text('色相'),
                        Slider(
                            value: hsv.hue,
                            min: 0,
                            max: 360,
                            onChanged: (v) => change(hsv.withHue(v))),
                        const Text('饱和度'),
                        Slider(
                            value: hsv.saturation,
                            onChanged: (v) => change(hsv.withSaturation(v))),
                        const Text('明度'),
                        Slider(
                            value: hsv.value,
                            onChanged: (v) => change(hsv.withValue(v))),
                        SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                                onPressed: () async {
                                  final value = input.text.trim();
                                  if (!RegExp(r'^#[a-fA-F0-9]{6}$')
                                      .hasMatch(value)) {
                                    setState(
                                        () => error = '请输入六位十六进制颜色，例如 #2563EB');
                                    return;
                                  }
                                  await ref
                                      .read(appearanceProvider.notifier)
                                      .update(accentSeed: value);
                                  if (sheetContext.mounted)
                                    Navigator.pop(sheetContext);
                                },
                                child: const Text('应用颜色'))),
                      ])));
            }));
    // Keep the controller alive until the sheet's reverse animation completes.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    input.dispose();
  }
}
