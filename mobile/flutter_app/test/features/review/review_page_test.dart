import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questrace_flutter/core/network/api_client.dart';
import 'package:questrace_flutter/features/review/review_page.dart';

void main() {
  testWidgets('review setup keeps stacked inputs apart', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response(
            requestOptions: options,
            data: switch (options.path) {
              final path when path.endsWith('/reviews/summary') => {
                'due': 3,
                'sessions': [],
              },
              final path when path.endsWith('/reviews/history') => [],
              _ => {'list': []},
            },
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(dio)],
        child: const MaterialApp(home: ReviewPage()),
      ),
    );
    await tester.pumpAndSettle();
    // 学科、标签搜索与题数上下相邻，之间必须留出间距而不是贴在一起。
    final fields = find.byType(TextField);
    for (var i = 1; i < fields.evaluate().length; i++) {
      expect(
        tester.getTopLeft(fields.at(i)).dy -
            tester.getBottomLeft(fields.at(i - 1)).dy,
        greaterThanOrEqualTo(12),
      );
    }
    expect(tester.takeException(), isNull);
  });
  for (final brightness in Brightness.values) {
    testWidgets('review hides answer and saves self assessment $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final dio = Dio();
      Map<String, dynamic>? submitted;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.method == 'POST') {
              submitted = Map<String, dynamic>.from(options.data as Map);
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {'mastery_status': 'learning', 'due_at': 2000000000},
                ),
              );
            } else {
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {
                    'id': 1,
                    'requested_count': 10,
                    'created_at': 1,
                    'items': [
                      {
                        'question_id': 1,
                        'question_core': 'cos x',
                        'standard_solution': 'answer hidden',
                        'source_image_url': '',
                        'result': '',
                        'deleted': false,
                      },
                    ],
                  },
                ),
              );
            }
          },
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [apiClientProvider.overrideWithValue(dio)],
          child: MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: const ReviewPage(sessionId: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('answer hidden'), findsNothing);
      await tester.tap(find.text('完成思考，查看答案'));
      await tester.pumpAndSettle();
      expect(find.text('answer hidden'), findsOneWidget);
      await tester.ensureVisible(find.text('会了'));
      await tester.tap(find.text('会了'));
      await tester.pumpAndSettle();
      expect(submitted?['result'], 'correct');
      expect(submitted?['submission_id'], isNotEmpty);
      expect(find.text('本次练习已完成，下次复习已安排。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
