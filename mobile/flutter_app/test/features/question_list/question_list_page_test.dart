import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:math_notebook_flutter/features/question_list/question_list_page.dart';
import 'package:math_notebook_flutter/features/question_list/question_repository.dart';
import 'package:math_notebook_flutter/shared/models/common_models.dart';
import 'package:math_notebook_flutter/shared/models/question_models.dart';

void main() {
  testWidgets('renders LaTeX question preview in question list cards', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questionRepositoryProvider.overrideWithValue(
            _FakeQuestionRepository(),
          ),
        ],
        child: const MaterialApp(
          home: QuestionListPage(
            initialFilter: ListQuestionFilter(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('错题列表'), findsOneWidget);
    expect(find.byType(Math), findsOneWidget);
    expect(find.byType(RepaintBoundary), findsWidgets);
    expect(find.byType(ClipRect), findsWidgets);
    expect(find.textContaining('已知函数在区间上的变化满足条件'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal,
      ),
      findsNothing,
    );
    expect(find.textContaining('掌握状态：未掌握'), findsOneWidget);
  });
}

class _FakeQuestionRepository extends QuestionRepository {
  _FakeQuestionRepository() : super(Dio());

  @override
  Future<PageResult<QuestionListItem>> listQuestions(
    ListQuestionFilter filter,
  ) async {
    return PageResult<QuestionListItem>(
      list: const [
        QuestionListItem(
          questionId: 1,
          questionCore: r'已知函数在区间上的变化满足条件，结合 $\frac{x^2+1}{2}=0$ 求最终结果并说明理由。',
          sourceImageUrl: '',
          subject: 'math',
          chapter: 'algebra',
          tags: TagGroups(),
          difficultyLevel: 3,
          masteryStatus: MasteryStatus.unmastered,
          createdAt: '2026-05-21T00:00:00Z',
        ),
      ],
      total: 1,
      page: 1,
      pageSize: 20,
    );
  }
}
