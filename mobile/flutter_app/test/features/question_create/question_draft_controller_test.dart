import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:math_notebook_flutter/core/storage/key_value_store.dart';
import 'package:math_notebook_flutter/core/storage/storage_keys.dart';
import 'package:math_notebook_flutter/features/question_create/question_draft_controller.dart';
import 'package:math_notebook_flutter/shared/models/common_models.dart';
import 'package:math_notebook_flutter/shared/models/question_models.dart';
import 'package:math_notebook_flutter/shared/utils/draft_navigation.dart';

void main() {
  test('recovers processing drafts back to OCR review and persists them',
      () async {
    final processingDraft = QuestionDraft(
      flowMode: DraftFlowMode.upload,
      sourceType: SourceType.image,
      sourceImageId: 7,
      sourceImageUrl: 'https://example.com/question.png',
      questionJson: const QuestionJson(questionCore: r'x^2+1=0'),
      status: DraftStatus.aiProcessing,
    );

    SharedPreferences.setMockInitialValues({
      StorageKeys.questionDraft: jsonEncode(processingDraft.toJson()),
    });
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
      ],
    );
    addTearDown(container.dispose);

    final recoveredDraft = container.read(questionDraftControllerProvider);

    expect(recoveredDraft, isNotNull);
    expect(recoveredDraft!.status, DraftStatus.ocrReviewing);
    expect(routeForDraft(recoveredDraft), '/questions/ocr-review');

    await container.read(questionDraftControllerProvider.notifier).flush();

    final persistedDraft = QuestionDraft.fromJson(
      jsonDecode(preferences.getString(StorageKeys.questionDraft)!)
          as Map<String, dynamic>,
    );
    expect(persistedDraft.status, DraftStatus.ocrReviewing);
  });
}
