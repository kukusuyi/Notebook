import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../shared/models/common_models.dart';
import '../../shared/models/question_models.dart';
import '../../shared/widgets/latex_block.dart';
import '../question_list/question_repository.dart';

class SimilarQuestionPage extends ConsumerStatefulWidget {
  const SimilarQuestionPage({
    super.key,
    required this.questionId,
  });

  final int questionId;

  @override
  ConsumerState<SimilarQuestionPage> createState() => _SimilarQuestionPageState();
}

class _SimilarQuestionPageState extends ConsumerState<SimilarQuestionPage> {
  late Future<SimilarQuestionResponse> _future;
  VectorType _vectorType = VectorType.semantic;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('相似题'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DropdownButtonFormField<VectorType>(
            value: _vectorType,
            decoration: const InputDecoration(
              labelText: '相似策略',
            ),
            items: VectorType.values
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text(item.label),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _vectorType = value;
                _future = _load();
              });
            },
          ),
          const SizedBox(height: 16),
          FutureBuilder<SimilarQuestionResponse>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(describeError(snapshot.error!)),
                );
              }

              final data = snapshot.data;
              if (data == null || data.list.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('暂无相似题结果。'),
                );
              }

              return Column(
                children: [
                  for (final item in data.list) ...[
                    Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: LatexBlock(item.questionCore),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '分数：${item.score.toStringAsFixed(3)}\n原因：${item.reason}',
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/questions/${item.questionId}'),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<SimilarQuestionResponse> _load() {
    return ref.read(questionRepositoryProvider).findSimilarQuestions(
          widget.questionId,
          SimilarQuestionRequest(
            vectorType: _vectorType,
            limit: 10,
            useTagFilter: true,
          ),
        );
  }
}
