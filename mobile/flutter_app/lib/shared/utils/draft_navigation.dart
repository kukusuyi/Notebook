import '../models/common_models.dart';
import '../models/question_models.dart';

bool hasActiveDraft(QuestionDraft? draft) {
  if (draft == null || draft.status == DraftStatus.saved) {
    return false;
  }

  if (draft.flowMode == DraftFlowMode.upload) {
    return true;
  }

  if (draft.status != DraftStatus.draft) {
    return true;
  }

  return _hasMeaningfulManualContent(draft);
}

bool _hasMeaningfulManualContent(QuestionDraft draft) {
  final questionJson = draft.questionJson;
  final tags = draft.tags;

  return draft.subject.trim().isNotEmpty ||
      draft.chapter.trim().isNotEmpty ||
      draft.chapterLocked ||
      questionJson.questionCore.trim().isNotEmpty ||
      questionJson.standardSolution.trim().isNotEmpty ||
      questionJson.wrongSolution.trim().isNotEmpty ||
      draft.semanticSummary.trim().isNotEmpty ||
      draft.mistakeSummary.trim().isNotEmpty ||
      tags.knowledgePoints.isNotEmpty ||
      tags.problemType.isNotEmpty ||
      tags.method.isNotEmpty ||
      tags.mistakeReason.isNotEmpty;
}

String routeForDraft(QuestionDraft draft) {
  switch (draft.status) {
    case DraftStatus.ocrProcessing:
    case DraftStatus.ocrReviewing:
      return '/questions/ocr-review';
    case DraftStatus.aiProcessing:
    case DraftStatus.aiReviewing:
      return '/questions/ai-review';
    default:
      return draft.flowMode == DraftFlowMode.upload
          ? '/questions/upload'
          : '/questions/create';
  }
}
