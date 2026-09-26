import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_exception.dart';
import '../models/ai_models.dart';
import '../../features/question_review/ai_repository.dart';

class AIModelSelectorCard extends ConsumerStatefulWidget {
  const AIModelSelectorCard({
    super.key,
    required this.providerName,
    required this.modelName,
    required this.onProviderChanged,
    required this.onModelChanged,
    this.title = 'AI 模型选择',
    this.description = '选择在电脑设置中保存的模型。',
  });
  final String providerName, modelName, title, description;
  final ValueChanged<String> onProviderChanged, onModelChanged;
  @override
  ConsumerState<AIModelSelectorCard> createState() =>
      _AIModelSelectorCardState();
}

class _AIModelSelectorCardState extends ConsumerState<AIModelSelectorCard> {
  List<AIProviderItem> _providers = [];
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _select(AIProviderItem? item) {
    widget.onProviderChanged(item?.providerName ?? '');
    widget.onModelChanged(item?.configuredModel ?? '');
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ref.read(aiRepositoryProvider).listProviders();
      if (!mounted) return;
      setState(() => _providers = response.list);
      AIProviderItem? selected;
      for (final item in _providers) {
        if (item.providerName == widget.providerName) selected = item;
      }
      selected ??= _providers.isEmpty ? null : _providers.first;
      _select(selected);
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final match = _providers.where(
      (p) => p.providerName == widget.providerName,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(widget.description),
            const SizedBox(height: 8),
            const Text('日常错题分析建议使用 32B 级小模型，可按效果与响应速度调整。'),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey('${widget.providerName}:${widget.modelName}'),
              initialValue: match.isEmpty ? null : widget.providerName,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '已配置模型'),
              items: _providers
                  .map(
                    (p) => DropdownMenuItem(
                      value: p.providerName,
                      child: Text(
                        '${p.providerName} · ${p.configuredModel}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _loading
                  ? null
                  : (name) {
                      _select(
                        _providers.firstWhere((p) => p.providerName == name),
                      );
                    },
            ),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) ...[
              Text(_error!),
              TextButton(onPressed: _load, child: const Text('重试')),
            ],
            if (!_loading && _error == null && _providers.isEmpty)
              const Text('AI 尚未配置，可直接保存题目，或在电脑设置中添加模型服务。'),
          ],
        ),
      ),
    );
  }
}
