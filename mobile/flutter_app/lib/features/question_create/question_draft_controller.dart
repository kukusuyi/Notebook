import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/ai_models.dart';
import '../../shared/models/common_models.dart';
import '../../shared/models/file_models.dart';
import '../../shared/models/question_models.dart';
import 'question_draft_repository.dart';

final questionDraftControllerProvider =
    NotifierProvider<QuestionDraftController, QuestionDraft?>(
  QuestionDraftController.new,
);

class QuestionDraftController extends Notifier<QuestionDraft?> {
  Future<void> _pendingPersistence = Future<void>.value();

  @override
  QuestionDraft? build() {
    final draft = ref.read(questionDraftRepositoryProvider).readDraft();
    return _normalizeRecoveredDraft(draft);
  }

  bool ensureManualDraft() {
    final current = state;
    if (current != null && current.status != DraftStatus.saved) {
      return current.flowMode == DraftFlowMode.manual;
    }

    _commit(QuestionDraft.emptyManual());
    return true;
  }

  void replaceWithUpload(UploadedImage image) {
    _commit(QuestionDraft.emptyUpload(image));
  }

  void updateBasicFields({
    required String subject,
    required String chapter,
    required QuestionJson questionJson,
    DraftFlowMode? flowMode,
    SourceType? sourceType,
  }) {
    final current = state ??
        const QuestionDraft(
          sourceType: SourceType.manual,
          flowMode: DraftFlowMode.manual,
        );

    _commit(
      current.copyWith(
        subject: subject,
        chapter: chapter,
        questionJson: questionJson,
        flowMode: flowMode,
        sourceType: sourceType,
      ),
    );
  }

  void setOcrResult({
    required QuestionJson questionJson,
    required OcrContext ocrContext,
  }) {
    final current = state ?? QuestionDraft.emptyManual();

    _commit(
      current.copyWith(
        questionJson: questionJson,
        ocrContext: ocrContext,
        status: DraftStatus.ocrReviewing,
      ),
    );
  }

  void updateChapterSelection({
    required String chapter,
    required bool locked,
  }) {
    final current = state ?? QuestionDraft.emptyManual();

    _commit(
      current.copyWith(
        chapter: chapter,
        chapterLocked: locked,
      ),
    );
  }

  void applyAiAnalysis(AnalyzeWrongQuestionResponse response) {
    final current = state ?? QuestionDraft.emptyManual();

    _commit(
      current.copyWith(
        chapter: response.chapter.isEmpty ? current.chapter : response.chapter,
        tags: response.tags,
        semanticSummary: response.semanticSummary,
        mistakeSummary: response.mistakeSummary,
        subject: current.subject.isEmpty ? 'math' : null,
        status: DraftStatus.aiReviewing,
      ),
    );
  }

  void updateReviewFields({
    required String subject,
    required String chapter,
    required TagGroups tags,
    required String semanticSummary,
    required String mistakeSummary,
    required int difficultyLevel,
    required MasteryStatus masteryStatus,
  }) {
    final current = state ?? QuestionDraft.emptyManual();

    _commit(
      current.copyWith(
        subject: subject,
        chapter: chapter,
        tags: tags,
        semanticSummary: semanticSummary,
        mistakeSummary: mistakeSummary,
        difficultyLevel: difficultyLevel,
        masteryStatus: masteryStatus,
      ),
    );
  }

  void updateAIModelSelection({
    required String providerName,
    required String modelName,
  }) {
    final current = state ?? QuestionDraft.emptyManual();

    _commit(
      current.copyWith(
        providerName: providerName,
        modelName: modelName,
      ),
    );
  }

  void markStatus(DraftStatus status) {
    final current = state;
    if (current == null) {
      return;
    }

    _commit(current.copyWith(status: status));
  }

  Future<void> flush() {
    return _pendingPersistence.catchError((_) {});
  }

  void clear() {
    state = null;
    _enqueuePersistence(
      () => ref.read(questionDraftRepositoryProvider).clearDraft(),
    );
  }

  void _commit(QuestionDraft draft) {
    state = draft;
    _enqueuePersistence(
      () => ref.read(questionDraftRepositoryProvider).saveDraft(draft),
    );
  }

  void _enqueuePersistence(Future<void> Function() action) {
    _pendingPersistence =
        _pendingPersistence.catchError((_) {}).then((_) => action());
  }

  QuestionDraft? _normalizeRecoveredDraft(QuestionDraft? draft) {
    if (draft == null) {
      return null;
    }

    final normalizedStatus = switch (draft.status) {
      DraftStatus.ocrProcessing ||
      DraftStatus.aiProcessing =>
        DraftStatus.ocrReviewing,
      _ => draft.status,
    };

    if (normalizedStatus == draft.status) {
      return draft;
    }

    final normalizedDraft = draft.copyWith(status: normalizedStatus);
    _enqueuePersistence(
      () =>
          ref.read(questionDraftRepositoryProvider).saveDraft(normalizedDraft),
    );
    return normalizedDraft;
  }
}
