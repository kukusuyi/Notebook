import 'dart:ui' as ui;
import 'package:questrace_flutter/core/network/api_exception.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/appearance.dart';
import '../../app/app_theme.dart';
import '../../app/theme_presets.dart';
import 'appearance_color_picker.dart';

class AppearanceCard extends ConsumerWidget {
  const AppearanceCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appearanceProvider);
    final controller = ref.read(appearanceProvider.notifier);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('外观', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('选择适合你的阅读空间。'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in flutterThemeCatalog.entries)
                  if (entry.key == customThemeKey)
                    ChoiceChip(
                      label: const Text('自定义'),
                      avatar: CircleAvatar(
                        backgroundColor:
                            prefs.customSeedColor ??
                            Theme.of(context).colorScheme.primary,
                        radius: 8,
                        child: prefs.customSeedColor == null
                            ? Icon(
                                Icons.palette,
                                size: 11,
                                color: Theme.of(context).colorScheme.onPrimary,
                              )
                            : null,
                      ),
                      selected: prefs.preset == customThemeKey,
                      onSelected: (_) => _chooseCustomColor(context, ref),
                    )
                  else
                    ChoiceChip(
                      label: Text(entry.value['label']),
                      avatar: CircleAvatar(
                        backgroundColor: parseThemeColor(entry.value['seed']),
                        radius: 8,
                      ),
                      selected: prefs.preset == entry.key,
                      onSelected: (_) => controller.update(preset: entry.key),
                    ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: prefs.mode,
              decoration: const InputDecoration(labelText: '显示模式'),
              items: const [
                DropdownMenuItem(value: 'system', child: Text('跟随系统')),
                DropdownMenuItem(value: 'light', child: Text('浅色')),
                DropdownMenuItem(value: 'dark', child: Text('深色')),
              ],
              onChanged: (value) => controller.update(mode: value),
            ),
            if (prefs.preset == customThemeKey) ...[
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: prefs.customSeedColor ?? Colors.grey,
                ),
                title: const Text('自定义颜色'),
                subtitle: Text(
                  prefs.accentSeed == null
                      ? '使用调色盘选择颜色'
                      : '${prefs.accentSeed} · 整套浅深外观由它生成',
                ),
                trailing: const Icon(Icons.palette_outlined),
                onTap: () => _chooseCustomColor(context, ref),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: prefs.material,
              decoration: const InputDecoration(labelText: '界面质感'),
              items: const [
                DropdownMenuItem(value: 'plain', child: Text('简洁纸面')),
                DropdownMenuItem(value: 'glass', child: Text('流光玻璃')),
                DropdownMenuItem(value: 'candy', child: Text('柔软糖果')),
              ],
              onChanged: (value) => controller.update(material: value),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: prefs.font,
              decoration: const InputDecoration(labelText: '字体风格'),
              items: const [
                DropdownMenuItem(value: 'system', child: Text('现代黑体')),
                DropdownMenuItem(value: 'rounded', child: Text('圆润人文')),
                DropdownMenuItem(value: 'serif', child: Text('书卷宋体')),
              ],
              onChanged: (value) => controller.update(font: value),
            ),
            const SizedBox(height: 12),
            const Text('字体使用本机可用字体，缺少时自动回退。背景只保存在此设备。'),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _chooseBackground(context, ref),
                  icon: const Icon(Icons.wallpaper),
                  label: const Text('选择背景图片'),
                ),
                if (prefs.background != null)
                  TextButton(
                    onPressed: () => controller.update(resetBackground: true),
                    child: const Text('移除背景'),
                  ),
              ],
            ),
            TextButton(
              onPressed: controller.reset,
              child: const Text('恢复默认外观'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _chooseBackground(BuildContext context, WidgetRef ref) async {
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image == null || !context.mounted) return;
      final bytes = await image.readAsBytes();
      if (bytes.length > 10 * 1024 * 1024) throw Exception('请选择 10 MB 以内的背景图片');
      final mime = bytes.length > 8 && bytes[0] == 137 && bytes[1] == 80
          ? 'png'
          : bytes.length > 2 && bytes[0] == 255 && bytes[1] == 216
          ? 'jpeg'
          : bytes.length > 12 &&
                ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP'
          ? 'webp'
          : null;
      if (mime == null) throw Exception('请选择 JPG、PNG 或 WebP 图片');
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      frame.image.dispose();
      codec.dispose();
      if (!context.mounted) return;
      await ref
          .read(appearanceProvider.notifier)
          .update(background: 'data:image/$mime;base64,${base64Encode(bytes)}');
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('背景设置失败：${describeError(error)}')),
        );
      }
    }
  }

  Future<void> _chooseCustomColor(BuildContext context, WidgetRef ref) async {
    final prefs = ref.read(appearanceProvider);
    final initial =
        prefs.customSeedColor ??
        (prefs.preset == customThemeKey
            ? Theme.of(context).colorScheme.primary
            : parseThemeColor(
                (flutterThemeCatalog[prefs.preset] ??
                        flutterThemeCatalog['blue'])!['seed']
                    as String,
              ));
    final color = await showModalBottomSheet<Color>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AppearanceColorPicker(initial: initial),
    );
    if (color == null || !context.mounted) return;
    final value =
        '#${(color.toARGB32() & 0xffffff).toRadixString(16).padLeft(6, '0')}';
    await ref
        .read(appearanceProvider.notifier)
        .update(preset: customThemeKey, accentSeed: value);
  }
}
