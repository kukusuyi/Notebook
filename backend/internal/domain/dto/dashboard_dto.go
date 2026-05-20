package dto

type DashboardDistributionItem struct {
	Type  string `json:"type"`
	Count int    `json:"count"`
}

type DashboardSummaryResponse struct {
	TotalQuestions      int                         `json:"total_questions"`
	TodayAdded          int                         `json:"today_added"`
	UnmasteredCount     int                         `json:"unmastered_count"`
	ImageBoundCount     int                         `json:"image_bound_count"`
	ActiveTagCount      int                         `json:"active_tag_count"`
	MasteryDistribution []DashboardDistributionItem `json:"mastery_distribution"`
	SourceDistribution  []DashboardDistributionItem `json:"source_distribution"`
}

type DashboardRecentResponse struct {
	List []QuestionListItem `json:"list"`
}

type DashboardTagsResponse struct {
	KnowledgePoints []TagItem `json:"knowledge_points"`
	MistakeReasons  []TagItem `json:"mistake_reasons"`
}
