import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/tag_models.dart';
import '../../shared/utils/platform_ui.dart';
import 'tag_repository.dart';

class TagManagePage extends ConsumerStatefulWidget {
  const TagManagePage({super.key});

  @override
  ConsumerState<TagManagePage> createState() => _TagManagePageState();
}

class _TagManagePageState extends ConsumerState<TagManagePage> {
  final _keywordController = TextEditingController();
  final _createNameController = TextEditingController();

  TagType? _selectedType;
  TagType _createType = TagType.knowledgePoint;
  bool _loading = false;
  bool _creating = false;
  List<TagItem> _tags = const <TagItem>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTags();
    });
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _createNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('标签管理'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSheet,
        icon: const Icon(Icons.add),
        label: const Text('新增标签'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadTags,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '筛选标签',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<TagType?>(
                      value: _selectedType,
                      decoration: const InputDecoration(labelText: '标签类型'),
                      items: [
                        const DropdownMenuItem<TagType?>(
                          value: null,
                          child: Text('全部类型'),
                        ),
                        ...TagType.values.map(
                          (item) => DropdownMenuItem<TagType?>(
                            value: item,
                            child: Text(item.label),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedType = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _keywordController,
                      decoration: const InputDecoration(
                        labelText: '标签关键词',
                        hintText: '输入标签名称后查询',
                      ),
                      textInputAction: TextInputAction.search,
                      onFieldSubmitted: (_) => _loadTags(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _loading ? null : _resetFilters,
                            child: const Text('重置'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _loading ? null : _loadTags,
                            child: const Text('查询'),
                          ),
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
                    Row(
                      children: [
                        Text(
                          '标签列表',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const Spacer(),
                        Text(
                          '共 ${_tags.length} 个',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_tags.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('暂无符合条件的标签'),
                        ),
                      )
                    else
                      ..._tags.map(
                        (tag) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _TagTile(
                            item: tag,
                            onDelete: () => _confirmDelete(tag),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadTags() async {
    setState(() {
      _loading = true;
    });

    try {
      final response = await ref.read(tagRepositoryProvider).listTags(
            tagType: _selectedType,
            keyword: _keywordController.text,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _tags = response.list;
      });
    } catch (error) {
      _showMessage('标签列表加载失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _resetFilters() {
    _keywordController.clear();
    setState(() {
      _selectedType = null;
    });
    _loadTags();
  }

  Future<void> _confirmDelete(TagItem tag) async {
    final confirmed = await showPlatformConfirmDialog(
      context: context,
      title: '删除标签',
      message: '确认删除“${tag.tagName}”吗？',
      confirmLabel: '删除',
      isDestructive: true,
    );

    if (!confirmed) {
      return;
    }

    try {
      await ref.read(tagRepositoryProvider).deleteTag(tag.tagId);
      _showMessage('标签已删除');
      await _loadTags();
    } catch (error) {
      _showMessage('标签删除失败：$error');
    }
  }

  Future<void> _showCreateSheet() {
    _createNameController.clear();
    _createType = _selectedType ?? TagType.knowledgePoint;

    return showPlatformModalSheet<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '新增标签',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _createNameController,
                    decoration: const InputDecoration(labelText: '标签名称'),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<TagType>(
                    value: _createType,
                    decoration: const InputDecoration(labelText: '标签类型'),
                    items: TagType.values
                        .map(
                          (item) => DropdownMenuItem<TagType>(
                            value: item,
                            child: Text(item.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setSheetState(() {
                        _createType = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _creating
                          ? null
                          : () => _submitCreate(
                                onFinish: () => Navigator.of(ctx).pop(),
                                onStateChanged: (value) {
                                  setSheetState(() {
                                    _creating = value;
                                  });
                                },
                              ),
                      child: Text(_creating ? '创建中...' : '创建标签'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      isScrollControlled: true,
    );
  }

  Future<void> _submitCreate({
    required VoidCallback onFinish,
    required ValueChanged<bool> onStateChanged,
  }) async {
    if (_createNameController.text.trim().isEmpty) {
      _showMessage('请输入标签名称');
      return;
    }

    onStateChanged(true);
    var success = false;
    try {
      await ref.read(tagRepositoryProvider).createTag(
            tagName: _createNameController.text,
            tagType: _createType,
          );
      success = true;
      _creating = false;
      onFinish();
      _showMessage('标签创建成功');
      await _loadTags();
    } catch (error) {
      _showMessage('标签创建失败：$error');
    } finally {
      if (mounted) {
        _creating = false;
        if (!success) {
          onStateChanged(false);
        }
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _TagTile extends StatelessWidget {
  const _TagTile({
    required this.item,
    required this.onDelete,
  });

  final TagItem item;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final typeColor = switch (item.tagType) {
      TagType.knowledgePoint => const Color(0xFF0C7A5C),
      TagType.problemType => const Color(0xFF5A6ACF),
      TagType.method => const Color(0xFFB7791F),
      TagType.mistakeReason => const Color(0xFFB44444),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD9E2DC)),
        color: Colors.white,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.tagName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MiniPill(
                        label: item.tagType.label,
                        backgroundColor: typeColor.withValues(alpha: 0.12),
                        textColor: typeColor,
                      ),
                      _MiniPill(
                        label: '使用 ${item.usageCount} 次',
                        backgroundColor: const Color(0xFFF1F4F2),
                        textColor: const Color(0xFF4B5A54),
                      ),
                      _MiniPill(
                        label: item.isActive ? '启用中' : '未启用',
                        backgroundColor: item.isActive
                            ? const Color(0xFFE2F6EC)
                            : const Color(0xFFF0F1F2),
                        textColor: item.isActive
                            ? const Color(0xFF0C7A5C)
                            : const Color(0xFF6A7370),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              tooltip: '删除标签',
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}
