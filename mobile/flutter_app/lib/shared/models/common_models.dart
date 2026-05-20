import 'json_helpers.dart';

enum SourceType {
  manual('manual'),
  image('image'),
  imported('import');

  const SourceType(this.value);

  final String value;

  String get label {
    switch (this) {
      case SourceType.manual:
        return '手动录入';
      case SourceType.image:
        return '图片识别';
      case SourceType.imported:
        return '导入';
    }
  }

  static SourceType fromValue(String raw) {
    return SourceType.values.firstWhere(
      (item) => item.value == raw,
      orElse: () => SourceType.manual,
    );
  }
}

enum MasteryStatus {
  unmastered('unmastered', '未掌握'),
  learning('learning', '学习中'),
  mastered('mastered', '已掌握');

  const MasteryStatus(this.value, this.label);

  final String value;
  final String label;

  static MasteryStatus fromValue(String raw) {
    return MasteryStatus.values.firstWhere(
      (item) => item.value == raw,
      orElse: () => MasteryStatus.unmastered,
    );
  }
}

enum SimilarityType {
  tag('tag'),
  semantic('semantic'),
  mistake('mistake'),
  hybrid('hybrid');

  const SimilarityType(this.value);

  final String value;

  static SimilarityType fromValue(String raw) {
    return SimilarityType.values.firstWhere(
      (item) => item.value == raw,
      orElse: () => SimilarityType.hybrid,
    );
  }
}

enum VectorType {
  semantic('semantic', '语义相似'),
  mistake('mistake', '错误模式相似');

  const VectorType(this.value, this.label);

  final String value;
  final String label;

  static VectorType fromValue(String raw) {
    return VectorType.values.firstWhere(
      (item) => item.value == raw,
      orElse: () => VectorType.semantic,
    );
  }
}

enum OcrConfidence {
  high('high', '高'),
  medium('medium', '中'),
  low('low', '低');

  const OcrConfidence(this.value, this.label);

  final String value;
  final String label;

  static OcrConfidence fromValue(String raw) {
    return OcrConfidence.values.firstWhere(
      (item) => item.value == raw,
      orElse: () => OcrConfidence.medium,
    );
  }
}

enum DraftFlowMode {
  manual('manual'),
  upload('upload');

  const DraftFlowMode(this.value);

  final String value;

  static DraftFlowMode fromValue(String raw) {
    return DraftFlowMode.values.firstWhere(
      (item) => item.value == raw,
      orElse: () => DraftFlowMode.manual,
    );
  }
}

enum DraftStatus {
  draft('draft'),
  imageUploaded('image_uploaded'),
  ocrProcessing('ocr_processing'),
  ocrReviewing('ocr_reviewing'),
  aiProcessing('ai_processing'),
  aiReviewing('ai_reviewing'),
  saved('saved'),
  vectorPending('vector_pending'),
  vectorReady('vector_ready'),
  vectorFailed('vector_failed');

  const DraftStatus(this.value);

  final String value;

  static DraftStatus fromValue(String raw) {
    return DraftStatus.values.firstWhere(
      (item) => item.value == raw,
      orElse: () => DraftStatus.draft,
    );
  }
}

class OptionItem<T> {
  const OptionItem({
    required this.label,
    required this.value,
  });

  final String label;
  final T value;
}

class PageResult<T> {
  const PageResult({
    required this.list,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<T> list;
  final int total;
  final int page;
  final int pageSize;

  factory PageResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parser,
  ) {
    return PageResult<T>(
      list: asObjectList(json['list'], parser),
      total: asInt(json['total']),
      page: asInt(json['page'], 1),
      pageSize: asInt(json['page_size'], 20),
    );
  }
}
