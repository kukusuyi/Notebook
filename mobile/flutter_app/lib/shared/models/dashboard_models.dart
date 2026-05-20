import 'json_helpers.dart';
import 'question_models.dart';
import 'tag_models.dart';

class DashboardDistributionItem {
  const DashboardDistributionItem({
    required this.type,
    required this.count,
  });

  final String type;
  final int count;

  factory DashboardDistributionItem.fromJson(Map<String, dynamic> json) {
    return DashboardDistributionItem(
      type: asString(json['type']),
      count: asInt(json['count']),
    );
  }
}

class DashboardSummary {
  const DashboardSummary({
    required this.totalQuestions,
    required this.todayAdded,
    required this.unmasteredCount,
    required this.imageBoundCount,
    required this.activeTagCount,
    required this.masteryDistribution,
    required this.sourceDistribution,
  });

  final int totalQuestions;
  final int todayAdded;
  final int unmasteredCount;
  final int imageBoundCount;
  final int activeTagCount;
  final List<DashboardDistributionItem> masteryDistribution;
  final List<DashboardDistributionItem> sourceDistribution;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      totalQuestions: asInt(json['total_questions']),
      todayAdded: asInt(json['today_added']),
      unmasteredCount: asInt(json['unmastered_count']),
      imageBoundCount: asInt(json['image_bound_count']),
      activeTagCount: asInt(json['active_tag_count']),
      masteryDistribution: asObjectList(
        json['mastery_distribution'],
        DashboardDistributionItem.fromJson,
      ),
      sourceDistribution: asObjectList(
        json['source_distribution'],
        DashboardDistributionItem.fromJson,
      ),
    );
  }
}

class DashboardRecentQuestions {
  const DashboardRecentQuestions({
    required this.list,
  });

  final List<QuestionListItem> list;

  factory DashboardRecentQuestions.fromJson(Map<String, dynamic> json) {
    return DashboardRecentQuestions(
      list: asObjectList(json['list'], QuestionListItem.fromJson),
    );
  }
}

class DashboardTopTags {
  const DashboardTopTags({
    required this.knowledgePoints,
    required this.mistakeReasons,
  });

  final List<TagItem> knowledgePoints;
  final List<TagItem> mistakeReasons;

  factory DashboardTopTags.fromJson(Map<String, dynamic> json) {
    return DashboardTopTags(
      knowledgePoints: asObjectList(
        json['knowledge_points'],
        TagItem.fromJson,
      ),
      mistakeReasons: asObjectList(
        json['mistake_reasons'],
        TagItem.fromJson,
      ),
    );
  }
}

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.summary,
    required this.recentQuestions,
    required this.topTags,
  });

  final DashboardSummary summary;
  final List<QuestionListItem> recentQuestions;
  final DashboardTopTags topTags;
}
