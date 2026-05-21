import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/effective_api_base_url.dart';
import '../../core/storage/auth_session_repository.dart';
import '../../shared/models/question_models.dart';
import '../../shared/utils/platform_ui.dart';
import '../../shared/widgets/question_compact_preview.dart';
import '../question_list/question_repository.dart';

enum _QuestionExportMode {
  withAnswers('with_answers', '携带答案导出'),
  questionsOnly('questions_only', '仅导出题目');

  const _QuestionExportMode(this.value, this.label);

  final String value;
  final String label;
}

class QuestionListPage extends ConsumerStatefulWidget {
  const QuestionListPage({
    super.key,
    required this.initialFilter,
    this.activeTagName = '',
  });

  final ListQuestionFilter initialFilter;
  final String activeTagName;

  @override
  ConsumerState<QuestionListPage> createState() => _QuestionListPageState();
}

class _QuestionListPageState extends ConsumerState<QuestionListPage> {
  late ListQuestionFilter _filter;
  final List<int> _selectedQuestionIds = <int>[];

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
  }

  @override
  void didUpdateWidget(covariant QuestionListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFilter != widget.initialFilter) {
      setState(() {
        _filter = widget.initialFilter;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final questions = ref.watch(questionListProvider(_filter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('错题列表'),
        actions: [
          if (_filter.hasAnyFilter || widget.activeTagName.isNotEmpty)
            TextButton(
              onPressed: () => context.go('/questions'),
              child: const Text('清空筛选'),
            ),
          IconButton(
            onPressed: _selectedQuestionIds.isEmpty ? null : _showExportOptions,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: '导出 PDF',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/questions/upload'),
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('新建'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(questionListProvider(_filter));
          await ref.read(questionListProvider(_filter).future);
        },
        child: questions.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 80),
              Text(
                '错题列表加载失败：$error',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          data: (data) {
            if (data.list.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  if (_filter.hasAnyFilter || widget.activeTagName.isNotEmpty)
                    _FilterSummaryCard(
                      filter: _filter,
                      activeTagName: widget.activeTagName,
                    ),
                  const SizedBox(height: 80),
                  const Center(child: Text('暂无符合条件的错题')),
                ],
              );
            }

            final headerChildren = <Widget>[
              if (_filter.hasAnyFilter || widget.activeTagName.isNotEmpty)
                _FilterSummaryCard(
                  filter: _filter,
                  activeTagName: widget.activeTagName,
                ),
              if (_filter.hasAnyFilter || widget.activeTagName.isNotEmpty)
                const SizedBox(height: 16),
              _SelectionSummaryCard(
                selectedCount: _selectedQuestionIds.length,
                onClear: _selectedQuestionIds.isEmpty
                    ? null
                    : () {
                        setState(() {
                          _selectedQuestionIds.clear();
                        });
                      },
                onExport:
                    _selectedQuestionIds.isEmpty ? null : _showExportOptions,
              ),
              const SizedBox(height: 16),
              Text(
                '共 ${data.total} 条错题',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
            ];

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(headerChildren),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
                  sliver: SliverList.builder(
                    itemCount: data.list.length,
                    itemBuilder: (context, index) {
                      final item = data.list[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _QuestionListCard(
                          item: item,
                          selected: _isQuestionSelected(item.questionId),
                          onToggleSelected: () =>
                              _toggleSelection(item.questionId),
                          onTap: () =>
                              context.push('/questions/${item.questionId}'),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  bool _isQuestionSelected(int questionId) {
    return _selectedQuestionIds.contains(questionId);
  }

  void _toggleSelection(int questionId) {
    setState(() {
      if (_isQuestionSelected(questionId)) {
        _selectedQuestionIds.remove(questionId);
        return;
      }

      _selectedQuestionIds.add(questionId);
    });
  }

  Future<void> _showExportOptions() async {
    if (_selectedQuestionIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择要导出的错题')),
      );
      return;
    }

    final exportMode = await showPlatformActionSheet<_QuestionExportMode>(
      context: context,
      title: '导出方式',
      actions: [
        for (final mode in _QuestionExportMode.values)
          PlatformActionSheetAction<_QuestionExportMode>(
            label: mode.label,
            value: mode,
            icon: mode == _QuestionExportMode.withAnswers
                ? Icons.fact_check_outlined
                : Icons.article_outlined,
          ),
      ],
    );

    if (!mounted || exportMode == null) {
      return;
    }

    await _exportSelectedQuestions(exportMode);
  }

  Future<void> _exportSelectedQuestions(_QuestionExportMode exportMode) async {
    if (_selectedQuestionIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择要导出的错题')),
      );
      return;
    }

    final token = ref.read(authSessionRepositoryProvider).readToken();
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前登录态无效，请重新登录后再试')),
      );
      return;
    }

    final apiBaseUrl = ref.read(effectiveApiBaseUrlProvider);
    final baseUri = Uri.parse(apiBaseUrl);
    final exportUri = baseUri
        .resolve('/api/v1/wrong-questions/export/print')
        .replace(queryParameters: <String, String>{
      'question_ids': _selectedQuestionIds.join(','),
      'export_mode': exportMode.value,
      'access_token': token,
    });

    bool launched = false;
    try {
      launched = await launchUrl(
        exportUri,
        mode: LaunchMode.platformDefault,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('打开导出页失败：$error')),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开系统浏览器，请检查设备设置')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已打开${exportMode.label}打印页，请在系统浏览器中保存为 PDF')),
    );
  }
}

class _QuestionListCard extends StatelessWidget {
  static const double _previewHeight = 76;

  const _QuestionListCard({
    required this.item,
    required this.selected,
    required this.onToggleSelected,
    required this.onTap,
  });

  final QuestionListItem item;
  final bool selected;
  final VoidCallback onToggleSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Checkbox(
                  value: selected,
                  onChanged: (_) => onToggleSelected(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RepaintBoundary(
                      child: QuestionCompactPreview(content: item.questionCore),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${item.subject} · ${item.chapter}\n掌握状态：${item.masteryStatus.label} · 来源：${item.sourceImageUrl.isNotEmpty ? '图片' : '文本'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterSummaryCard extends StatelessWidget {
  const _FilterSummaryCard({
    required this.filter,
    required this.activeTagName,
  });

  final ListQuestionFilter filter;
  final String activeTagName;

  @override
  Widget build(BuildContext context) {
    final chips = <String>[
      if (filter.masteryStatus != null) '掌握状态：${filter.masteryStatus!.label}',
      if (filter.sourceType != null) '来源：${filter.sourceType!.label}',
      if (activeTagName.isNotEmpty) '标签：$activeTagName',
      if (activeTagName.isEmpty && filter.tagIds.isNotEmpty)
        '标签筛选：${filter.tagIds.length} 项',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '当前筛选',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips
                  .map(
                    (item) => DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF7F2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Text(item),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionSummaryCard extends StatelessWidget {
  const _SelectionSummaryCard({
    required this.selectedCount,
    this.onClear,
    this.onExport,
  });

  final int selectedCount;
  final VoidCallback? onClear;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 220,
              child: Text(
                selectedCount == 0 ? '还没有选择要导出的错题' : '已选 $selectedCount 道错题',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            TextButton(
              onPressed: onClear,
              child: const Text('清空'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: onExport,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('导出 PDF'),
            ),
          ],
        ),
      ),
    );
  }
}
