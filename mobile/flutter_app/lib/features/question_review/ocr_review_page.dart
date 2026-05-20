import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../shared/models/question_models.dart';
import '../../shared/widgets/ai_model_selector_card.dart';
import '../../shared/widgets/latex_review_field.dart';
import '../../shared/widgets/remote_image_card.dart';
import '../question_create/question_draft_controller.dart';
import 'ai_repository.dart';
import 'question_flow_service.dart';

class OcrReviewPage extends ConsumerStatefulWidget {
  const OcrReviewPage({super.key});

  @override
  ConsumerState<OcrReviewPage> createState() => _OcrReviewPageState();
}

class _OcrReviewPageState extends ConsumerState<OcrReviewPage> {
  final _questionCoreController = TextEditingController();
  final _standardSolutionController = TextEditingController();
  final _wrongSolutionController = TextEditingController();
  late Future<List<String>> _chaptersFuture;
  bool _hydrated = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _chaptersFuture = _loadChapters();
  }

  @override
  void dispose() {
    _questionCoreController.dispose();
    _standardSolutionController.dispose();
    _wrongSolutionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(questionDraftControllerProvider);
    _hydrateIfNeeded(draft);

    if (draft == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('OCR 确认')),
        body: const Center(
          child: Text('当前没有可确认的 OCR 草稿。'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR 结果确认'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '丢弃草稿',
            onPressed: () => _confirmDiscard(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (draft.sourceImageUrl.isNotEmpty)
            RemoteImageCard(imageUrl: draft.sourceImageUrl),
          if (draft.sourceImageUrl.isNotEmpty) const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OCR 置信度：${draft.ocrContext?.ocrConfidence.label ?? '未知'}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if ((draft.ocrContext?.uncertainParts ?? const <String>[])
                      .isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final item in draft.ocrContext!.uncertainParts)
                          Chip(label: Text(item)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  LatexReviewField(
                    title: '题目主干',
                    controller: _questionCoreController,
                    placeholder: '支持普通文本与 LaTeX 混排',
                    emptyPreviewText: '暂无题目主干',
                    onChanged: (_) => _persistDraft(),
                  ),
                  const SizedBox(height: 12),
                  LatexReviewField(
                    title: '标准解',
                    controller: _standardSolutionController,
                    placeholder: '可以为空',
                    emptyPreviewText: '暂无标准解',
                    onChanged: (_) => _persistDraft(),
                  ),
                  const SizedBox(height: 12),
                  LatexReviewField(
                    title: '错误解',
                    controller: _wrongSolutionController,
                    placeholder: '可以为空，但建议保留原始错误过程',
                    emptyPreviewText: '暂无错误解',
                    onChanged: (_) => _persistDraft(),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<List<String>>(
                    future: _chaptersFuture,
                    builder: (context, snapshot) {
                      final chapters = snapshot.data ?? const <String>[];
                      final chapterItems = <DropdownMenuItem<String>>[
                        const DropdownMenuItem(
                          value: '',
                          child: Text('自动判断章节'),
                        ),
                        ...chapters.map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item),
                          ),
                        ),
                      ];

                      return Column(
                        children: [
                          DropdownButtonFormField<String>(
                            value: _matchChapterValue(draft.chapter, chapters),
                            decoration: const InputDecoration(
                              labelText: '章节',
                            ),
                            items: chapterItems,
                            onChanged: (value) {
                              _updateChapter(value ?? '');
                            },
                          ),
                          if (snapshot.connectionState == ConnectionState.waiting)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: LinearProgressIndicator(minHeight: 2),
                            ),
                          if (snapshot.hasError)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  describeError(snapshot.error!),
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          AIModelSelectorCard(
            providerName: draft.providerName,
            modelName: draft.modelName,
            title: '选择分析模型',
            description: 'OCR 内容确认无误后，选择下一步用于错误分析的模型。',
            onProviderChanged: (value) {
              final current = ref.read(questionDraftControllerProvider);
              ref
                  .read(questionDraftControllerProvider.notifier)
                  .updateAIModelSelection(
                    providerName: value,
                    modelName: current?.modelName ?? '',
                  );
            },
            onModelChanged: (value) {
              final current = ref.read(questionDraftControllerProvider);
              ref
                  .read(questionDraftControllerProvider.notifier)
                  .updateAIModelSelection(
                    providerName: current?.providerName ?? '',
                    modelName: value,
                  );
            },
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submitting ? null : _analyze,
            child: Text(_submitting ? '分析中...' : '继续 AI 分析'),
          ),
        ],
      ),
    );
  }

  void _hydrateIfNeeded(QuestionDraft? draft) {
    if (_hydrated || draft == null) {
      return;
    }

    _questionCoreController.text = draft.questionJson.questionCore;
    _standardSolutionController.text = draft.questionJson.standardSolution;
    _wrongSolutionController.text = draft.questionJson.wrongSolution;
    _hydrated = true;
  }

  void _persistDraft() {
    final draft = ref.read(questionDraftControllerProvider);
    if (draft == null) {
      return;
    }

    ref.read(questionDraftControllerProvider.notifier).updateBasicFields(
          subject: draft.subject,
          chapter: draft.chapter,
          questionJson: QuestionJson(
            questionCore: _questionCoreController.text.trim(),
            standardSolution: _standardSolutionController.text.trim(),
            wrongSolution: _wrongSolutionController.text.trim(),
          ),
          flowMode: draft.flowMode,
          sourceType: draft.sourceType,
        );
  }

  Future<List<String>> _loadChapters() async {
    final response = await ref.read(aiRepositoryProvider).listChapters();
    return response.list;
  }

  String _matchChapterValue(String current, List<String> chapters) {
    if (current.isEmpty) {
      return '';
    }
    for (final item in chapters) {
      if (item == current) {
        return current;
      }
    }
    return '';
  }

  void _updateChapter(String chapter) {
    ref.read(questionDraftControllerProvider.notifier).updateChapterSelection(
          chapter: chapter,
          locked: chapter.trim().isNotEmpty,
        );
  }

  Future<void> _analyze() async {
    if (_questionCoreController.text.trim().isEmpty) {
      _showMessage('请先确认题目主干');
      return;
    }

    final draft = ref.read(questionDraftControllerProvider);
    if (draft == null ||
        draft.providerName.trim().isEmpty ||
        draft.modelName.trim().isEmpty) {
      _showMessage('请先选择 AI 模型厂商和模型名称');
      return;
    }

    _persistDraft();

    setState(() {
      _submitting = true;
    });

    try {
      await ref.read(questionFlowServiceProvider).analyzeCurrentDraft();
      if (mounted) {
        context.push('/questions/ai-review');
      }
    } catch (error) {
      _showMessage(describeError(error));
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _confirmDiscard() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('丢弃草稿'),
        content: const Text('确定要丢弃当前草稿吗？丢弃后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(questionDraftControllerProvider.notifier).clear();
              context.go('/dashboard');
            },
            child: const Text('确定丢弃'),
          ),
        ],
      ),
    );
  }
}
