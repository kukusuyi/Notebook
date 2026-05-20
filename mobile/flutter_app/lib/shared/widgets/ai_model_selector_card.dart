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
    this.description = '先选厂商，再选择该厂商当前可调用的模型。',
  });

  final String providerName;
  final String modelName;
  final ValueChanged<String> onProviderChanged;
  final ValueChanged<String> onModelChanged;
  final String title;
  final String description;

  @override
  ConsumerState<AIModelSelectorCard> createState() =>
      _AIModelSelectorCardState();
}

class _AIModelSelectorCardState extends ConsumerState<AIModelSelectorCard> {
  late Future<List<AIProviderItem>> _providersFuture;
  Future<List<AIProviderModelItem>>? _modelsFuture;
  String _modelsProviderName = '';

  @override
  void initState() {
    super.initState();
    _providersFuture = _loadProviders();
  }

  @override
  void didUpdateWidget(covariant AIModelSelectorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.providerName != oldWidget.providerName) {
      _ensureModelsFuture(widget.providerName);
    }
  }

  @override
  Widget build(BuildContext context) {
    _ensureModelsFuture(widget.providerName);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.description,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _refresh,
                  child: const Text('刷新'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<AIProviderItem>>(
              future: _providersFuture,
              builder: (context, snapshot) {
                final providers = snapshot.data ?? const <AIProviderItem>[];
                final loading =
                    snapshot.connectionState == ConnectionState.waiting;

                return Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _matchValue(
                        widget.providerName,
                        providers.map((item) => item.providerName),
                      ),
                      decoration: const InputDecoration(
                        labelText: '模型厂商',
                      ),
                      items: providers
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.providerName,
                              child: Text(item.providerName),
                            ),
                          )
                          .toList(),
                      onChanged: loading || providers.isEmpty
                          ? null
                          : (value) async {
                              if (value == null) {
                                return;
                              }
                              widget.onProviderChanged(value);
                              widget.onModelChanged('');
                              setState(() {
                                _modelsFuture = _loadModels(value);
                                _modelsProviderName = value;
                              });
                              await _ensureSelectionForProvider(value);
                            },
                    ),
                    if (snapshot.hasError) ...[
                      const SizedBox(height: 8),
                      _InlineMessage(message: describeError(snapshot.error!)),
                    ],
                    const SizedBox(height: 12),
                    _buildModelDropdown(hasProviders: providers.isNotEmpty),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelDropdown({
    required bool hasProviders,
  }) {
    if (!hasProviders ||
        widget.providerName.isEmpty ||
        _modelsFuture == null) {
      return DropdownButtonFormField<String>(
        value: null,
        decoration: const InputDecoration(
          labelText: '模型名称',
        ),
        items: const [],
        onChanged: null,
      );
    }

    return FutureBuilder<List<AIProviderModelItem>>(
      future: _modelsFuture,
      builder: (context, snapshot) {
        final models = snapshot.data ?? const <AIProviderModelItem>[];
        final loading =
            snapshot.connectionState == ConnectionState.waiting;

        return Column(
          children: [
            DropdownButtonFormField<String>(
              value: _matchValue(
                widget.modelName,
                models.map((item) => item.modelName),
              ),
              decoration: const InputDecoration(
                labelText: '模型名称',
              ),
              items: models
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.modelName,
                      child: Text(item.modelName),
                    ),
                  )
                  .toList(),
              onChanged: loading || models.isEmpty
                  ? null
                  : (value) {
                      if (value == null) {
                        return;
                      }
                      widget.onModelChanged(value);
                    },
            ),
            if (loading)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (snapshot.hasError) ...[
              const SizedBox(height: 8),
              _InlineMessage(message: describeError(snapshot.error!)),
            ],
            if (!loading &&
                !snapshot.hasError &&
                widget.providerName.isNotEmpty &&
                models.isEmpty) ...[
              const SizedBox(height: 8),
              const _InlineMessage(
                message: '当前厂商没有返回可用模型，请检查后端配置。',
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _modelsFuture = null;
      _modelsProviderName = '';
      _providersFuture = _loadProviders();
    });
    try {
      await _providersFuture;
    } catch (_) {
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<List<AIProviderItem>> _loadProviders() async {
    final response = await ref.read(aiRepositoryProvider).listProviders();
    final providers = response.list;

    if (providers.isEmpty) {
      if (widget.providerName.isNotEmpty) {
        widget.onProviderChanged('');
      }
      if (widget.modelName.isNotEmpty) {
        widget.onModelChanged('');
      }
      return providers;
    }

    final matchedProvider = _findProvider(providers, widget.providerName);
    final nextProvider = matchedProvider?.providerName ?? providers.first.providerName;
    if (nextProvider != widget.providerName) {
      widget.onProviderChanged(nextProvider);
    }

    await _ensureSelectionForProvider(nextProvider);
    return providers;
  }

  Future<void> _ensureSelectionForProvider(String providerName) async {
    if (providerName.isEmpty) {
      return;
    }

    final models = await _loadModels(providerName);
    if (!mounted) {
      return;
    }

    setState(() {
      _modelsFuture = Future<List<AIProviderModelItem>>.value(models);
      _modelsProviderName = providerName;
    });

    final matchedModel = _findModel(models, widget.modelName);
    final nextModel =
        matchedModel?.modelName ?? (models.isNotEmpty ? models.first.modelName : '');
    if (nextModel != widget.modelName) {
      widget.onModelChanged(nextModel);
    }
  }

  Future<List<AIProviderModelItem>> _loadModels(String providerName) async {
    final response =
        await ref.read(aiRepositoryProvider).listProviderModels(providerName);
    return response.list;
  }

  void _ensureModelsFuture(String providerName) {
    if (providerName.isEmpty || _modelsProviderName == providerName) {
      return;
    }

    _modelsFuture = _loadModels(providerName);
    _modelsProviderName = providerName;
  }

  String? _matchValue(String current, Iterable<String> candidates) {
    if (current.isEmpty) {
      return null;
    }

    for (final item in candidates) {
      if (item == current) {
        return current;
      }
    }
    return null;
  }

  AIProviderItem? _findProvider(
    List<AIProviderItem> providers,
    String providerName,
  ) {
    for (final item in providers) {
      if (item.providerName == providerName) {
        return item;
      }
    }
    return null;
  }

  AIProviderModelItem? _findModel(
    List<AIProviderModelItem> models,
    String modelName,
  ) {
    for (final item in models) {
      if (item.modelName == modelName) {
        return item;
      }
    }
    return null;
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        message,
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
          fontSize: 12,
        ),
      ),
    );
  }
}
