import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/discovery/lan_discovery.dart';
import '../../core/storage/app_settings_controller.dart';

class LanComputerPicker extends ConsumerStatefulWidget {
  const LanComputerPicker({super.key});
  @override
  ConsumerState<LanComputerPicker> createState() => _LanComputerPickerState();
}

class _LanComputerPickerState extends ConsumerState<LanComputerPicker> {
  bool _busy = false;
  String? _message;
  List<LanComputer> _computers = [];
  Future<void> _scan() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final found = await LanDiscovery().scan();
      if (mounted) {
        setState(() {
          _computers = found;
          if (found.isEmpty) _message = '未找到电脑，请确认处于同一局域网并已允许本地网络访问，也可手动填写地址。';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _message = '无法搜索，请在系统设置中允许本地网络访问，或手动填写地址。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect(LanComputer computer) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(appSettingsControllerProvider.notifier)
          .setApiBaseUrlOverride(computer.url, expectedDeviceId: computer.id);
      if (mounted) {
        setState(() => _message = '已连接 ${computer.name}，换网后将自动寻找这台电脑。');
      }
    } catch (_) {
      if (mounted) setState(() => _message = '连接失败，请确认电脑在线后重试。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextButton.icon(
        onPressed: _busy ? null : _scan,
        icon: const Icon(Icons.wifi_find),
        label: Text(_busy ? '正在连接局域网…' : '搜索局域网电脑'),
      ),
      for (final c in _computers)
        ListTile(
          title: Text(c.name),
          subtitle: Text(c.url),
          onTap: _busy ? null : () => _connect(c),
        ),
      if (_message != null) Text(_message!),
    ],
  );
}
