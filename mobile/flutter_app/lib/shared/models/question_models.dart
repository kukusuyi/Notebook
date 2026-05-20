import 'common_models.dart';
import 'file_models.dart';
import 'json_helpers.dart';

class QuestionJson {
  const QuestionJson({
    this.questionCore = '',
    this.standardSolution = '',
    this.wrongSolution = '',
  });

  final String questionCore;
  final String standardSolution;
  final String wrongSolution;

  QuestionJson copyWith({
    String? questionCore,
    String? standardSolution,
    String? wrongSolution,
  }) {
    return QuestionJson(
      questionCore: questionCore ?? this.questionCore,
      standardSolution: standardSolution ?? this.standardSolution,
      wrongSolution: wrongSolution ?? this.wrongSolution,
    );
  }

  factory QuestionJson.fromJson(Map<String, dynamic> json) {
    return QuestionJson(
      questionCore: asString(json['question_core']),
      standardSolution: asString(json['standard_solution']),
      wrongSolution: asString(json['wrong_solution']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question_core': questionCore,
      'standard_solution': standardSolution,
      'wrong_solution': wrongSolution,
    };
  }
}

class TagGroups {
  const TagGroups({
    this.knowledgePoints = const <String>[],
    this.problemType = const <String>[],
    this.method = const <String>[],
    this.mistakeReason = const <String>[],
  });

  final List<String> knowledgePoints;
  final List<String> problemType;
  final List<String> method;
  final List<String> mistakeReason;

  TagGroups copyWith({
    List<String>? knowledgePoints,
    List<String>? problemType,
    List<String>? method,
    List<String>? mistakeReason,
  }) {
    return TagGroups(
      knowledgePoints: knowledgePoints ?? this.knowledgePoints,
      problemType: problemType ?? this.problemType,
      method: method ?? this.method,
      mistakeReason: mistakeReason ?? this.mistakeReason,
    );
  }

  factory TagGroups.fromJson(Map<String, dynamic> json) {
    return TagGroups(
      knowledgePoints: asStringList(json['knowledge_points']),
      problemType: asStringList(json['problem_type']),
      method: asStringList(json['method']),
      mistakeReason: asStringList(json['mistake_reason']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'knowledge_points': knowledgePoints,
      'problem_type': problemType,
      'method': method,
      'mistake_reason': mistakeReason,
    };
  }
}

class OcrContext {
  const OcrContext({
    this.ocrConfidence = OcrConfidence.medium,
    this.uncertainParts = const <String>[],
  });

  final OcrConfidence ocrConfidence;
  final List<String> uncertainParts;

  factory OcrContext.fromJson(Map<String, dynamic> json) {
    return OcrContext(
      ocrConfidence: OcrConfidence.fromValue(
        asString(json['ocr_confidence'], OcrConfidence.medium.value),
      ),
      uncertainParts: asStringList(json['uncertain_parts']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ocr_confidence': ocrConfidence.value,
      'uncertain_parts': uncertainParts,
    };
  }
}

class QuestionDraft {
  const QuestionDraft({
    this.providerName = '',
    this.modelName = '',
    this.sourceType = SourceType.manual,
    this.sourceImageId,
    this.sourceImageUrl = '',
    this.subject = '',
    this.chapter = '',
    this.chapterLocked = false,
    this.questionJson = const QuestionJson(),
    this.tags = const TagGroups(),
    this.semanticSummary = '',
    this.mistakeSummary = '',
    this.difficultyLevel = 3,
    this.masteryStatus = MasteryStatus.unmastered,
    this.ocrContext,
    this.flowMode = DraftFlowMode.manual,
    this.status = DraftStatus.draft,
  });

  final String providerName;
  final String modelName;
  final SourceType sourceType;
  final int? sourceImageId;
  final String sourceImageUrl;
  final String subject;
  final String chapter;
  final bool chapterLocked;
  final QuestionJson questionJson;
  final TagGroups tags;
  final String semanticSummary;
  final String mistakeSummary;
  final int difficultyLevel;
  final MasteryStatus masteryStatus;
  final OcrContext? ocrContext;
  final DraftFlowMode flowMode;
  final DraftStatus status;

  factory QuestionDraft.emptyManual() {
    return const QuestionDraft(
      sourceType: SourceType.manual,
      flowMode: DraftFlowMode.manual,
      status: DraftStatus.draft,
    );
  }

  factory QuestionDraft.emptyUpload(UploadedImage image) {
    return QuestionDraft(
      sourceType: SourceType.image,
      sourceImageId: image.imageId,
      sourceImageUrl: image.imageUrl,
      flowMode: DraftFlowMode.upload,
      status: DraftStatus.imageUploaded,
    );
  }

  QuestionDraft copyWith({
    String? providerName,
    String? modelName,
    SourceType? sourceType,
    int? sourceImageId,
    bool clearSourceImageId = false,
    String? sourceImageUrl,
    String? subject,
    String? chapter,
    bool? chapterLocked,
    QuestionJson? questionJson,
    TagGroups? tags,
    String? semanticSummary,
    String? mistakeSummary,
    int? difficultyLevel,
    MasteryStatus? masteryStatus,
    OcrContext? ocrContext,
    bool clearOcrContext = false,
    DraftFlowMode? flowMode,
    DraftStatus? status,
  }) {
    return QuestionDraft(
      providerName: providerName ?? this.providerName,
      modelName: modelName ?? this.modelName,
      sourceType: sourceType ?? this.sourceType,
      sourceImageId: clearSourceImageId
          ? null
          : (sourceImageId ?? this.sourceImageId),
      sourceImageUrl: sourceImageUrl ?? this.sourceImageUrl,
      subject: subject ?? this.subject,
      chapter: chapter ?? this.chapter,
      chapterLocked: chapterLocked ?? this.chapterLocked,
      questionJson: questionJson ?? this.questionJson,
      tags: tags ?? this.tags,
      semanticSummary: semanticSummary ?? this.semanticSummary,
      mistakeSummary: mistakeSummary ?? this.mistakeSummary,
      difficultyLevel: difficultyLevel ?? this.difficultyLevel,
      masteryStatus: masteryStatus ?? this.masteryStatus,
      ocrContext: clearOcrContext ? null : (ocrContext ?? this.ocrContext),
      flowMode: flowMode ?? this.flowMode,
      status: status ?? this.status,
    );
  }

  factory QuestionDraft.fromJson(Map<String, dynamic> json) {
    return QuestionDraft(
      providerName: asString(json['provider_name']),
      modelName: asString(json['model_name']),
      sourceType: SourceType.fromValue(
        asString(json['source_type'], SourceType.manual.value),
      ),
      sourceImageId: json['source_image_id'] == null
          ? null
          : asInt(json['source_image_id']),
      sourceImageUrl: asString(json['source_image_url']),
      subject: asString(json['subject']),
      chapter: asString(json['chapter']),
      chapterLocked: asBool(json['chapter_locked']),
      questionJson: QuestionJson.fromJson(asJsonMap(json['question_json'])),
      tags: TagGroups.fromJson(asJsonMap(json['tags'])),
      semanticSummary: asString(json['semantic_summary']),
      mistakeSummary: asString(json['mistake_summary']),
      difficultyLevel: asInt(json['difficulty_level'], 3),
      masteryStatus: MasteryStatus.fromValue(
        asString(json['mastery_status'], MasteryStatus.unmastered.value),
      ),
      ocrContext: json['ocr_context'] == null
          ? null
          : OcrContext.fromJson(asJsonMap(json['ocr_context'])),
      flowMode: DraftFlowMode.fromValue(
        asString(json['flow_mode'], DraftFlowMode.manual.value),
      ),
      status: DraftStatus.fromValue(
        asString(json['status'], DraftStatus.draft.value),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'provider_name': providerName,
      'model_name': modelName,
      'source_type': sourceType.value,
      'source_image_id': sourceImageId,
      'source_image_url': sourceImageUrl,
      'subject': subject,
      'chapter': chapter,
      'chapter_locked': chapterLocked,
      'question_json': questionJson.toJson(),
      'tags': tags.toJson(),
      'semantic_summary': semanticSummary,
      'mistake_summary': mistakeSummary,
      'difficulty_level': difficultyLevel,
      'mastery_status': masteryStatus.value,
      'ocr_context': ocrContext?.toJson(),
      'flow_mode': flowMode.value,
      'status': status.value,
    };
  }

  CreateWrongQuestionPayload toCreatePayload() {
    return CreateWrongQuestionPayload(
      sourceType: sourceType,
      sourceImageId: sourceImageId,
      sourceImageUrl: sourceImageUrl,
      subject: subject,
      chapter: chapter,
      questionJson: questionJson,
      tags: tags,
      semanticSummary: semanticSummary,
      mistakeSummary: mistakeSummary,
      difficultyLevel: difficultyLevel,
      masteryStatus: masteryStatus,
    );
  }
}

class CreateWrongQuestionPayload {
  const CreateWrongQuestionPayload({
    required this.sourceType,
    required this.sourceImageUrl,
    required this.subject,
    required this.chapter,
    required this.questionJson,
    required this.tags,
    required this.semanticSummary,
    required this.mistakeSummary,
    required this.difficultyLevel,
    required this.masteryStatus,
    this.sourceImageId,
  });

  final SourceType sourceType;
  final int? sourceImageId;
  final String sourceImageUrl;
  final String subject;
  final String chapter;
  final QuestionJson questionJson;
  final TagGroups tags;
  final String semanticSummary;
  final String mistakeSummary;
  final int difficultyLevel;
  final MasteryStatus masteryStatus;

  Map<String, dynamic> toJson() {
    return {
      'source_type': sourceType.value,
      'source_image_id': sourceImageId,
      'source_image_url': sourceImageUrl,
      'subject': subject,
      'chapter': chapter,
      'question_json': questionJson.toJson(),
      'tags': tags.toJson(),
      'semantic_summary': semanticSummary,
      'mistake_summary': mistakeSummary,
      'difficulty_level': difficultyLevel,
      'mastery_status': masteryStatus.value,
    };
  }
}

class UpdateWrongQuestionPayload {
  const UpdateWrongQuestionPayload({
    required this.questionJson,
    required this.subject,
    required this.chapter,
    required this.tags,
    required this.sourceImageUrl,
    required this.semanticSummary,
    required this.mistakeSummary,
    required this.difficultyLevel,
    required this.masteryStatus,
    this.sourceImageId,
  });

  final QuestionJson questionJson;
  final String subject;
  final String chapter;
  final TagGroups tags;
  final int? sourceImageId;
  final String sourceImageUrl;
  final String semanticSummary;
  final String mistakeSummary;
  final int difficultyLevel;
  final MasteryStatus masteryStatus;

  Map<String, dynamic> toJson() {
    return {
      'question_json': questionJson.toJson(),
      'subject': subject,
      'chapter': chapter,
      'tags': tags.toJson(),
      'source_image_id': sourceImageId,
      'source_image_url': sourceImageUrl,
      'semantic_summary': semanticSummary,
      'mistake_summary': mistakeSummary,
      'difficulty_level': difficultyLevel,
      'mastery_status': masteryStatus.value,
    };
  }
}

class CreateWrongQuestionResponse {
  const CreateWrongQuestionResponse({
    required this.questionId,
  });

  final int questionId;

  factory CreateWrongQuestionResponse.fromJson(Map<String, dynamic> json) {
    return CreateWrongQuestionResponse(
      questionId: asInt(json['question_id']),
    );
  }
}

class QuestionListItem {
  const QuestionListItem({
    required this.questionId,
    required this.questionCore,
    required this.sourceImageUrl,
    required this.subject,
    required this.chapter,
    required this.tags,
    required this.difficultyLevel,
    required this.masteryStatus,
    required this.createdAt,
    this.sourceImageId,
  });

  final int questionId;
  final String questionCore;
  final int? sourceImageId;
  final String sourceImageUrl;
  final String subject;
  final String chapter;
  final TagGroups tags;
  final int difficultyLevel;
  final MasteryStatus masteryStatus;
  final String createdAt;

  factory QuestionListItem.fromJson(Map<String, dynamic> json) {
    return QuestionListItem(
      questionId: asInt(json['question_id']),
      questionCore: asString(json['question_core']),
      sourceImageId: json['source_image_id'] == null
          ? null
          : asInt(json['source_image_id']),
      sourceImageUrl: asString(json['source_image_url']),
      subject: asString(json['subject']),
      chapter: asString(json['chapter']),
      tags: TagGroups.fromJson(asJsonMap(json['tags'])),
      difficultyLevel: asInt(json['difficulty_level']),
      masteryStatus: MasteryStatus.fromValue(
        asString(json['mastery_status'], MasteryStatus.unmastered.value),
      ),
      createdAt: asString(json['created_at']),
    );
  }
}

class QuestionDetail extends QuestionListItem {
  const QuestionDetail({
    required super.questionId,
    required super.questionCore,
    required super.sourceImageUrl,
    required super.subject,
    required super.chapter,
    required super.tags,
    required super.difficultyLevel,
    required super.masteryStatus,
    required super.createdAt,
    required this.standardSolution,
    required this.wrongSolution,
    required this.semanticSummary,
    required this.mistakeSummary,
    required this.sourceType,
    required this.updatedAt,
    super.sourceImageId,
  });

  final String standardSolution;
  final String wrongSolution;
  final String semanticSummary;
  final String mistakeSummary;
  final SourceType sourceType;
  final String updatedAt;

  factory QuestionDetail.fromJson(Map<String, dynamic> json) {
    return QuestionDetail(
      questionId: asInt(json['question_id']),
      questionCore: asString(json['question_core']),
      sourceImageId: json['source_image_id'] == null
          ? null
          : asInt(json['source_image_id']),
      sourceImageUrl: asString(json['source_image_url']),
      subject: asString(json['subject']),
      chapter: asString(json['chapter']),
      tags: TagGroups.fromJson(asJsonMap(json['tags'])),
      difficultyLevel: asInt(json['difficulty_level']),
      masteryStatus: MasteryStatus.fromValue(
        asString(json['mastery_status'], MasteryStatus.unmastered.value),
      ),
      createdAt: asString(json['created_at']),
      standardSolution: asString(json['standard_solution']),
      wrongSolution: asString(json['wrong_solution']),
      semanticSummary: asString(json['semantic_summary']),
      mistakeSummary: asString(json['mistake_summary']),
      sourceType: SourceType.fromValue(
        asString(json['source_type'], SourceType.manual.value),
      ),
      updatedAt: asString(json['updated_at']),
    );
  }
}

class SimilarQuestionRequest {
  const SimilarQuestionRequest({
    required this.vectorType,
    this.limit = 10,
    this.useTagFilter = true,
  });

  final VectorType vectorType;
  final int limit;
  final bool useTagFilter;

  Map<String, dynamic> toJson() {
    return {
      'vector_type': vectorType.value,
      'limit': limit,
      'use_tag_filter': useTagFilter,
    };
  }
}

class SimilarQuestionItem {
  const SimilarQuestionItem({
    required this.questionId,
    required this.score,
    required this.similarityType,
    required this.questionCore,
    required this.sourceImageUrl,
    required this.matchedTags,
    required this.reason,
    required this.tags,
    this.sourceImageId,
  });

  final int questionId;
  final double score;
  final SimilarityType similarityType;
  final String questionCore;
  final int? sourceImageId;
  final String sourceImageUrl;
  final List<String> matchedTags;
  final String reason;
  final TagGroups tags;

  factory SimilarQuestionItem.fromJson(Map<String, dynamic> json) {
    return SimilarQuestionItem(
      questionId: asInt(json['question_id']),
      score: asDouble(json['score']),
      similarityType: SimilarityType.fromValue(
        asString(json['similarity_type'], SimilarityType.hybrid.value),
      ),
      questionCore: asString(json['question_core']),
      sourceImageId: json['source_image_id'] == null
          ? null
          : asInt(json['source_image_id']),
      sourceImageUrl: asString(json['source_image_url']),
      matchedTags: asStringList(json['matched_tags']),
      reason: asString(json['reason']),
      tags: TagGroups.fromJson(asJsonMap(json['tags'])),
    );
  }
}

class SimilarQuestionResponse {
  const SimilarQuestionResponse({
    required this.list,
  });

  final List<SimilarQuestionItem> list;

  factory SimilarQuestionResponse.fromJson(Map<String, dynamic> json) {
    return SimilarQuestionResponse(
      list: asObjectList(json['list'], SimilarQuestionItem.fromJson),
    );
  }
}

class ListQuestionFilter {
  const ListQuestionFilter({
    this.page = 1,
    this.pageSize = 20,
    this.subject,
    this.chapter,
    this.keyword,
    this.masteryStatus,
    this.difficultyLevel,
    this.sourceType,
    this.tagIds = const <int>[],
  });

  final int page;
  final int pageSize;
  final String? subject;
  final String? chapter;
  final String? keyword;
  final MasteryStatus? masteryStatus;
  final int? difficultyLevel;
  final SourceType? sourceType;
  final List<int> tagIds;

  bool get hasAnyFilter =>
      (subject?.isNotEmpty ?? false) ||
      (chapter?.isNotEmpty ?? false) ||
      (keyword?.isNotEmpty ?? false) ||
      masteryStatus != null ||
      difficultyLevel != null ||
      sourceType != null ||
      tagIds.isNotEmpty;

  ListQuestionFilter copyWith({
    int? page,
    int? pageSize,
    String? subject,
    String? chapter,
    String? keyword,
    MasteryStatus? masteryStatus,
    bool clearMasteryStatus = false,
    int? difficultyLevel,
    bool clearDifficultyLevel = false,
    SourceType? sourceType,
    bool clearSourceType = false,
    List<int>? tagIds,
  }) {
    return ListQuestionFilter(
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      subject: subject ?? this.subject,
      chapter: chapter ?? this.chapter,
      keyword: keyword ?? this.keyword,
      masteryStatus: clearMasteryStatus
          ? null
          : (masteryStatus ?? this.masteryStatus),
      difficultyLevel: clearDifficultyLevel
          ? null
          : (difficultyLevel ?? this.difficultyLevel),
      sourceType: clearSourceType ? null : (sourceType ?? this.sourceType),
      tagIds: tagIds ?? this.tagIds,
    );
  }

  Map<String, dynamic> toQueryParameters() {
    return {
      'page': page,
      'page_size': pageSize,
      if (subject != null && subject!.isNotEmpty) 'subject': subject,
      if (chapter != null && chapter!.isNotEmpty) 'chapter': chapter,
      if (keyword != null && keyword!.isNotEmpty) 'keyword': keyword,
      if (masteryStatus != null) 'mastery_status': masteryStatus!.value,
      if (difficultyLevel != null) 'difficulty_level': difficultyLevel,
      if (sourceType != null) 'source_type': sourceType!.value,
      if (tagIds.isNotEmpty) 'tag_ids': tagIds.join(','),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is ListQuestionFilter &&
        other.page == page &&
        other.pageSize == pageSize &&
        other.subject == subject &&
        other.chapter == chapter &&
        other.keyword == keyword &&
        other.masteryStatus == masteryStatus &&
        other.difficultyLevel == difficultyLevel &&
        other.sourceType == sourceType &&
        _listEquals(other.tagIds, tagIds);
  }

  @override
  int get hashCode => Object.hash(
        page,
        pageSize,
        subject,
        chapter,
        keyword,
        masteryStatus,
        difficultyLevel,
        sourceType,
        Object.hashAll(tagIds),
      );
}

class RecognizedWrongQuestion {
  const RecognizedWrongQuestion({
    required this.questionJson,
    required this.ocrContext,
  });

  final QuestionJson questionJson;
  final OcrContext ocrContext;

  factory RecognizedWrongQuestion.fromJson(Map<String, dynamic> json) {
    return RecognizedWrongQuestion(
      questionJson: QuestionJson.fromJson(json),
      ocrContext: OcrContext.fromJson(json),
    );
  }
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (left.length != right.length) {
    return false;
  }

  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }

  return true;
}
