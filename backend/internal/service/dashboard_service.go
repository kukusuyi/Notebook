package service

import (
	"context"
	"sort"
	"time"

	"mathnotebook/backend/internal/domain/dto"
	"mathnotebook/backend/internal/domain/enum"
	"mathnotebook/backend/internal/domain/model"
	"mathnotebook/backend/internal/pkg/timeutil"
	"mathnotebook/backend/internal/repository"
)

type DashboardService struct {
	questionRepo repository.QuestionRepository
	tagRepo      repository.TagRepository
}

func NewDashboardService(questionRepo repository.QuestionRepository, tagRepo repository.TagRepository) *DashboardService {
	return &DashboardService{
		questionRepo: questionRepo,
		tagRepo:      tagRepo,
	}
}

func (s *DashboardService) Summary(ctx context.Context) (dto.DashboardSummaryResponse, error) {
	userID, err := RequireUserID(ctx)
	if err != nil {
		return dto.DashboardSummaryResponse{}, err
	}

	metrics, err := s.questionRepo.DashboardMetrics(userID, time.Now())
	if err != nil {
		return dto.DashboardSummaryResponse{}, err
	}

	allTags, err := s.tagRepo.List(repository.TagFilter{UserID: userID})
	if err != nil {
		return dto.DashboardSummaryResponse{}, err
	}

	return dto.DashboardSummaryResponse{
		TotalQuestions:      metrics.TotalQuestions,
		TodayAdded:          metrics.TodayAdded,
		UnmasteredCount:     metrics.UnmasteredCount,
		ImageBoundCount:     metrics.ImageBoundCount,
		ActiveTagCount:      len(allTags),
		MasteryDistribution: buildDashboardDistribution(metrics.MasteryStatusMap, []string{"unmastered", "learning", "mastered"}),
		SourceDistribution:  buildDashboardDistribution(metrics.SourceTypeMap, []string{"manual", "image", "import"}),
	}, nil
}

func (s *DashboardService) Recent(ctx context.Context, limit int) (dto.DashboardRecentResponse, error) {
	userID, err := RequireUserID(ctx)
	if err != nil {
		return dto.DashboardRecentResponse{}, err
	}

	if limit <= 0 {
		limit = 4
	}
	if limit > 12 {
		limit = 12
	}

	items, _, err := s.questionRepo.List(repository.QuestionFilter{
		UserID:   userID,
		Page:     1,
		PageSize: limit,
	})
	if err != nil {
		return dto.DashboardRecentResponse{}, err
	}

	response := dto.DashboardRecentResponse{
		List: make([]dto.QuestionListItem, 0, len(items)),
	}
	for _, item := range items {
		response.List = append(response.List, dto.QuestionListItem{
			QuestionID:      item.ID,
			QuestionCore:    item.QuestionCore,
			SourceImageID:   item.SourceImageID,
			SourceImageURL:  item.SourceImageURL,
			Subject:         item.Subject,
			Chapter:         item.Chapter,
			Tags:            toTagGroups(item.Tags),
			DifficultyLevel: item.DifficultyLevel,
			MasteryStatus:   item.MasteryStatus,
			CreatedAt:       timeutil.Format(item.CreatedAt),
		})
	}

	return response, nil
}

func (s *DashboardService) Tags(ctx context.Context, limit int) (dto.DashboardTagsResponse, error) {
	userID, err := RequireUserID(ctx)
	if err != nil {
		return dto.DashboardTagsResponse{}, err
	}

	if limit <= 0 {
		limit = 6
	}
	if limit > 12 {
		limit = 12
	}

	knowledgePoints, err := s.tagRepo.List(repository.TagFilter{
		UserID:  userID,
		TagType: string(enum.TagTypeKnowledgePoint),
	})
	if err != nil {
		return dto.DashboardTagsResponse{}, err
	}

	mistakeReasons, err := s.tagRepo.List(repository.TagFilter{
		UserID:  userID,
		TagType: string(enum.TagTypeMistakeReason),
	})
	if err != nil {
		return dto.DashboardTagsResponse{}, err
	}

	return dto.DashboardTagsResponse{
		KnowledgePoints: toDashboardTagItems(knowledgePoints, limit),
		MistakeReasons:  toDashboardTagItems(mistakeReasons, limit),
	}, nil
}

func buildDashboardDistribution(values map[string]int, order []string) []dto.DashboardDistributionItem {
	items := make([]dto.DashboardDistributionItem, 0, len(order))
	for _, key := range order {
		items = append(items, dto.DashboardDistributionItem{
			Type:  key,
			Count: values[key],
		})
	}

	sort.SliceStable(items, func(i, j int) bool {
		if items[i].Count == items[j].Count {
			return indexOf(order, items[i].Type) < indexOf(order, items[j].Type)
		}
		return items[i].Count > items[j].Count
	})

	return items
}

func toDashboardTagItems(items []model.Tag, limit int) []dto.TagItem {
	if len(items) > limit {
		items = items[:limit]
	}

	result := make([]dto.TagItem, 0, len(items))
	for _, item := range items {
		result = append(result, dto.TagItem{
			TagID:      item.ID,
			TagName:    item.TagName,
			TagType:    item.TagType,
			UsageCount: item.UsageCount,
			IsActive:   item.IsActive,
		})
	}

	return result
}

func indexOf(values []string, target string) int {
	for index, value := range values {
		if value == target {
			return index
		}
	}
	return len(values)
}
