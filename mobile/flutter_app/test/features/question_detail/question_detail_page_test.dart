import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:math_notebook_flutter/features/question_detail/question_detail_page.dart';
import 'package:math_notebook_flutter/features/question_list/question_repository.dart';
import 'package:math_notebook_flutter/shared/models/common_models.dart';
import 'package:math_notebook_flutter/shared/models/question_models.dart';

void main() {
  testWidgets('wraps LaTeX content in question detail sections',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questionRepositoryProvider.overrideWithValue(
            _FakeQuestionRepository(),
          ),
        ],
        child: const MaterialApp(
          home: QuestionDetailPage(questionId: 1),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('错题详情'), findsOneWidget);
    expect(find.byType(Math), findsWidgets);
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
  Future<QuestionDetail> getQuestionDetail(int questionId) async {
    return const QuestionDetail(
      questionId: 1,
      questionCore: r'已知函数在区间上的变化满足条件，结合 $\frac{x^2+1}{2}=0$ 求最终结果并说明理由。',
      sourceImageUrl: '',
      subject: 'math',
      chapter: 'algebra',
      tags: TagGroups(),
      difficultyLevel: 3,
      masteryStatus: MasteryStatus.unmastered,
      createdAt: '2026-05-22T00:00:00Z',
      standardSolution:
          r'由条件可得 $\frac{x^4+2x^2+1}{x^2+1}=\frac{(x^2+1)^2}{x^2+1}=x^2+1$，继续化简并讨论。',
      wrongSolution: r'错误地把 $x^2+1=0$ 直接写成 $x=1$。',
      semanticSummary: '这是一个关于方程与函数性质结合的题目。',
      mistakeSummary: '忽略了平方项与常数项的整体关系。',
      sourceType: SourceType.manual,
      updatedAt: '2026-05-22T00:00:00Z',
    );
  }
}
