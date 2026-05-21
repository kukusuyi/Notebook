import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_environment.dart';
import '../../core/storage/app_settings_controller.dart';
import '../auth/auth_controller.dart';

const _presetColors = <Color>[
  Color(0xFF0C7A5C), // Green (default)
  Color(0xFF1565C0), // Blue
  Color(0xFF3F51B5), // Indigo
  Color(0xFF7B1FA2), // Purple
  Color(0xFFC2185B), // Pink
  Color(0xFFD32F2F), // Red
  Color(0xFFE64A19), // Deep Orange
  Color(0xFFF57C00), // Orange
  Color(0xFFFFA000), // Amber
  Color(0xFF00796B), // Teal
];

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _apiBaseUrlController = TextEditingController();
  bool _hydrated = false;

  @override
  void dispose() {
    _apiBaseUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final environment = ref.watch(appEnvironmentProvider);
    final settings = ref.watch(appSettingsControllerProvider);
    _hydrateIfNeeded(environment.defaultApiBaseUrl, settings.apiBaseUrlOverride);

    final effectiveBaseUrl = settings.apiBaseUrlOverride.isNotEmpty
        ? settings.apiBaseUrlOverride
        : environment.defaultApiBaseUrl;
    final effectiveBaseUrlLabel =
        effectiveBaseUrl.isEmpty ? '未配置，请填写后端地址' : effectiveBaseUrl;

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '接口环境',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text('默认地址：${environment.defaultApiBaseUrl}'),
                  const SizedBox(height: 4),
                  Text('默认来源：${environment.defaultApiBaseUrlSource}'),
                  const SizedBox(height: 8),
                  Text('当前生效：$effectiveBaseUrlLabel'),
                  const SizedBox(height: 8),
                  Text(
                    '正式包默认地址请修改 ${AppEnvironment.actualConfigAssetPath}；真机联调请改成宿主机局域网地址，设置页覆盖只影响当前设备。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _apiBaseUrlController,
                    decoration: const InputDecoration(
                      labelText: '自定义 API Base URL',
                      hintText: '留空则使用配置文件里的默认地址',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => _save(environment.defaultApiBaseUrl),
                    child: const Text('保存地址'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: () => context.push('/tags'),
                    icon: const Icon(Icons.sell_outlined),
                    label: const Text('进入标签管理'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '主题色',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '选择你喜欢的主题色',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final color in _presetColors)
                        GestureDetector(
                          onTap: () => _selectThemeColor(color),
                          child: _ColorCircle(
                            color: color,
                            selected: settings.themeColorSeed != null &&
                                settings.themeColorSeed! == color.toARGB32(),
                          ),
                        ),
                      const SizedBox(width: 8),
                      _ResetColorChip(
                        onTap: () => _selectThemeColor(null),
                        isReset: settings.themeColorSeed == null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '账号',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: _logout,
                    child: const Text('退出登录'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _hydrateIfNeeded(String defaultBaseUrl, String overrideBaseUrl) {
    if (_hydrated) {
      return;
    }

    _apiBaseUrlController.text =
        overrideBaseUrl.isNotEmpty ? overrideBaseUrl : defaultBaseUrl;
    _hydrated = true;
  }

  Future<void> _save(String defaultBaseUrl) async {
    final raw = _apiBaseUrlController.text.trim();
    final nextValue = raw == defaultBaseUrl ? '' : raw;
    await ref
        .read(appSettingsControllerProvider.notifier)
        .setApiBaseUrlOverride(nextValue);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('接口地址已保存')),
      );
    }
  }

  Future<void> _selectThemeColor(Color? color) async {
    await ref
        .read(appSettingsControllerProvider.notifier)
        .setThemeColorSeed(color?.toARGB32());
  }

  Future<void> _logout() async {
    await ref.read(authControllerProvider.notifier).logout();
    if (mounted) {
      context.go('/auth');
    }
  }
}

class _ColorCircle extends StatelessWidget {
  const _ColorCircle({required this.color, required this.selected});
  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: selected
            ? Border.all(color: Colors.black54, width: 3)
            : Border.all(color: Colors.black12, width: 1),
        boxShadow: selected
            ? [BoxShadow(color: color.withAlpha(128), blurRadius: 8, spreadRadius: 1)]
            : null,
      ),
    );
  }
}

class _ResetColorChip extends StatelessWidget {
  const _ResetColorChip({required this.onTap, required this.isReset});
  final VoidCallback onTap;
  final bool isReset;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isReset ? Colors.black54 : Colors.black12,
            width: isReset ? 3 : 1,
          ),
        ),
        child: const Center(child: Text('默认', style: TextStyle(fontSize: 10))),
      ),
    );
  }
}
