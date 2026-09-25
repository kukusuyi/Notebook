import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questrace_flutter/core/network/server_capabilities.dart';
import 'package:questrace_flutter/shared/widgets/server_status_card.dart';

void main() {
  testWidgets('index failure preserves service capabilities', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverCapabilitiesProvider.overrideWith(
            (ref) async => {
              'ocr_enabled': true,
              'ai_enabled': true,
              'embedding_enabled': false,
            },
          ),
          vectorJobsProvider.overrideWith(
            (ref) async => throw const FormatException('bad'),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: ServerStatusCard())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('OCR：可用 · AI：可用'), findsOneWidget);
    expect(find.textContaining('索引加载失败'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('empty index counts are zero', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverCapabilitiesProvider.overrideWith(
            (ref) async => {
              'ocr_enabled': false,
              'ai_enabled': false,
              'embedding_enabled': true,
            },
          ),
          vectorJobsProvider.overrideWith((ref) async => {}),
        ],
        child: const MaterialApp(home: Scaffold(body: ServerStatusCard())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('索引完成 0 · 等待 0 · 失败 0'), findsOneWidget);
  });
}
