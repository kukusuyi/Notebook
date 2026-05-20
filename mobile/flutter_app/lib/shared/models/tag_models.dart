import 'json_helpers.dart';

enum TagType {
  knowledgePoint('knowledge_point', '知识点'),
  problemType('problem_type', '题型'),
  method('method', '解法'),
  mistakeReason('mistake_reason', '错因');

  const TagType(this.value, this.label);

  final String value;
  final String label;

  static TagType fromValue(String raw) {
    return TagType.values.firstWhere(
      (item) => item.value == raw,
      orElse: () => TagType.knowledgePoint,
    );
  }
}

class TagItem {
  const TagItem({
    required this.tagId,
    required this.tagName,
    required this.tagType,
    required this.usageCount,
    required this.isActive,
  });

  final int tagId;
  final String tagName;
  final TagType tagType;
  final int usageCount;
  final bool isActive;

  factory TagItem.fromJson(Map<String, dynamic> json) {
    return TagItem(
      tagId: asInt(json['tag_id']),
      tagName: asString(json['tag_name']),
      tagType: TagType.fromValue(asString(json['tag_type'])),
      usageCount: asInt(json['usage_count']),
      isActive: json['is_active'] == true,
    );
  }
}

class TagListResponse {
  const TagListResponse({
    required this.list,
  });

  final List<TagItem> list;

  factory TagListResponse.fromJson(Map<String, dynamic> json) {
    return TagListResponse(
      list: asObjectList(json['list'], TagItem.fromJson),
    );
  }
}
