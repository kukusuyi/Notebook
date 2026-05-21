import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../shared/models/common_models.dart';
import '../../shared/models/question_models.dart';
import '../../shared/utils/draft_navigation.dart';
import '../../shared/widgets/ai_model_selector_card.dart';
import '../../shared/widgets/question_json_editor.dart';
import '../question_review/question_flow_service.dart';
import 'question_draft_controller.dart';

class QuestionCreatePage extends ConsumerStatefulWidget {
  const QuestionCreatePage({super.key});

  @override
  ConsumerState<QuestionCreatePage> createState() => _QuestionCreatePageState();
}

class _QuestionCreatePageState extends ConsumerState<QuestionCreatePage> {
  final _subjectController = TextEditingController();
  final _chapterController = TextEditingController();
  final _questionCoreController = TextEditingController();
  final _standardSolutionController = TextEditingController();
  final _wrongSolutionController = TextEditingController();
  final _jsonController = TextEditingController();
  bool _hydrated = false;
  bool _submitting = false;
  String? _jsonError;
  QuestionCreateMode _mode = QuestionCreateMode.form;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final draft = ref.read(questionDraftControllerProvider);
      if (!mounted || draft == null || draft.status == DraftStatus.saved) {
        return;
      }
      if (draft.flowMode != DraftFlowMode.manual) {
        context.go(routeForDraft(draft));
      }
    });
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _chapterController.dispose();
    _questionCoreController.dispose();
    _standardSolutionController.dispose();
    _wrongSolutionController.dispose();
    _jsonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(questionDraftControllerProvider);
    _hydrateIfNeeded(draft);

    return Scaffold(
      appBar: AppBar(
        title: const Text('手动录入'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '丢弃草稿',
            onPressed: () => _confirmDiscard(),
          ),
        ],
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
                    '先把题干、标准解和错误解录进去，AI 分析后再补标签与总结。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  AIModelSelectorCard(
                    providerName: draft?.providerName ?? '',
                    modelName: draft?.modelName ?? '',
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
                  SegmentedButton<QuestionCreateMode>(
                    segments: const [
                      ButtonSegment(
                        value: QuestionCreateMode.form,
                        icon: Icon(Icons.view_stream_outlined),
                        label: Text('表单录入'),
                      ),
                      ButtonSegment(
                        value: QuestionCreateMode.json,
                        icon: Icon(Icons.data_object_outlined),
                        label: Text('JSON 录入'),
                      ),
                    ],
                    selected: <QuestionCreateMode>{_mode},
                    onSelectionChanged: (selection) {
                      final nextMode = selection.first;
                      if (nextMode == QuestionCreateMode.json) {
                        _syncJsonFromForm();
                      } else {
                        _applyJsonToForm(showError: true);
                      }

                      setState(() {
                        _mode = nextMode;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _subjectController,
                    decoration: const InputDecoration(labelText: '学科'),
                    onChanged: (_) => _persistDraft(),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _chapterController,
                    decoration: const InputDecoration(labelText: '章节'),
                    onChanged: (_) => _persistDraft(),
                  ),
                  const SizedBox(height: 12),
                  if (_mode == QuestionCreateMode.form) ...[
                    TextFormField(
                      controller: _questionCoreController,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(labelText: '题目主干'),
                      onChanged: (_) => _persistDraft(),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _standardSolutionController,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(labelText: '标准解'),
                      onChanged: (_) => _persistDraft(),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _wrongSolutionController,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(labelText: '错误解'),
                      onChanged: (_) => _persistDraft(),
                    ),
                  ] else
                    QuestionJsonEditor(
                      controller: _jsonController,
                      errorText: _jsonError,
                      onChanged: (_) {
                        _persistDraft();
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: _submitting
                      ? null
                      : () {
                          context.go('/questions/upload');
                        },
                  child: const Text('改用图片录入'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _submitting ? null : _analyze,
                  child: Text(_submitting ? '分析中...' : '调用 AI 分析'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _hydrateIfNeeded(QuestionDraft? draft) {
    if (_hydrated || draft == null) {
      return;
    }

    _subjectController.text = draft.subject;
    _chapterController.text = draft.chapter;
    _questionCoreController.text = draft.questionJson.questionCore;
    _standardSolutionController.text = draft.questionJson.standardSolution;
    _wrongSolutionController.text = draft.questionJson.wrongSolution;
    _jsonController.text = formatQuestionJson(draft.questionJson);
    _hydrated = true;
  }

  void _persistDraft() {
    final questionJson = _currentQuestionJson();
    if (questionJson == null) {
      return;
    }

    ref.read(questionDraftControllerProvider.notifier).updateBasicFields(
          subject: _subjectController.text.trim(),
          chapter: _chapterController.text.trim(),
          questionJson: questionJson,
          flowMode: DraftFlowMode.manual,
          sourceType: SourceType.manual,
        );
  }

  Future<void> _analyze() async {
    if (_mode == QuestionCreateMode.json && !_applyJsonToForm(showError: true)) {
      return;
    }

    final draft = ref.read(questionDraftControllerProvider);
    if (draft == null ||
        draft.providerName.trim().isEmpty ||
        draft.modelName.trim().isEmpty) {
      _showMessage('请先选择 AI 模型厂商和模型名称');
      return;
    }

    if (_questionCoreController.text.trim().isEmpty) {
      _showMessage('请先填写题目主干');
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

  QuestionJson? _currentQuestionJson() {
    if (_mode == QuestionCreateMode.json) {
      try {
        final parsed = tryParseQuestionJson(_jsonController.text) ??
            const QuestionJson();
        if (_jsonError != null) {
          setState(() {
            _jsonError = null;
          });
        }
        return parsed;
      } on FormatException catch (error) {
        if (_jsonError != error.message) {
          setState(() {
            _jsonError = error.message;
          });
        }
        return null;
      } on Object {
        const message = 'JSON 格式错误，请检查花括号、引号和字段名';
        if (_jsonError != message) {
          setState(() {
            _jsonError = message;
          });
        }
        return null;
      }
    }

    if (_jsonError != null) {
      setState(() {
        _jsonError = null;
      });
    }
    return QuestionJson(
      questionCore: _questionCoreController.text.trim(),
      standardSolution: _standardSolutionController.text.trim(),
      wrongSolution: _wrongSolutionController.text.trim(),
    );
  }

  bool _applyJsonToForm({required bool showError}) {
    try {
      final parsed = tryParseQuestionJson(_jsonController.text) ??
          const QuestionJson();
      _questionCoreController.text = parsed.questionCore;
      _standardSolutionController.text = parsed.standardSolution;
      _wrongSolutionController.text = parsed.wrongSolution;
      if (_jsonError != null) {
        setState(() {
          _jsonError = null;
        });
      }
      _persistDraft();
      return true;
    } on FormatException catch (error) {
      if (showError) {
        setState(() {
          _jsonError = error.message;
        });
        _showMessage(error.message);
      }
      return false;
    } on Object {
      const message = 'JSON 格式错误，请检查花括号、引号和字段名';
      if (showError) {
        setState(() {
          _jsonError = message;
        });
        _showMessage(message);
      }
      return false;
    }
  }

  void _syncJsonFromForm() {
    final raw = formatQuestionJson(
      QuestionJson(
        questionCore: _questionCoreController.text.trim(),
        standardSolution: _standardSolutionController.text.trim(),
        wrongSolution: _wrongSolutionController.text.trim(),
      ),
    );

    if (_jsonController.text != raw) {
      _jsonController.text = raw;
    }
    if (_jsonError != null) {
      setState(() {
        _jsonError = null;
      });
    }
  }
}

enum QuestionCreateMode {
  form,
  json,
}
