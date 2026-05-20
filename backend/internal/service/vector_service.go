package service

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"strings"
	"time"

	"github.com/google/uuid"

	"mathnotebook/backend/internal/config"
	"mathnotebook/backend/internal/domain/enum"
	"mathnotebook/backend/internal/domain/model"
	aiinfra "mathnotebook/backend/internal/infra/ai"
	"mathnotebook/backend/internal/infra/qdrant"
	"mathnotebook/backend/internal/repository"
)

type VectorService struct {
	config          config.VectorConfig
	vectorRepo      repository.VectorRepository
	embeddingClient aiinfra.EmbeddingClient
	qdrantClient    *qdrant.Client
}

type SimilarSearchItem struct {
	QuestionID int64
	Score      float64
}

func NewVectorService(
	cfg config.VectorConfig,
	vectorRepo repository.VectorRepository,
	embeddingClient aiinfra.EmbeddingClient,
	qdrantClient *qdrant.Client,
) *VectorService {
	return &VectorService{
		config:          cfg,
		vectorRepo:      vectorRepo,
		embeddingClient: embeddingClient,
		qdrantClient:    qdrantClient,
	}
}

func (s *VectorService) Upsert(question model.WrongQuestion) error {
	if err := s.upsertByType(context.Background(), question, string(enum.VectorTypeSemantic), strings.TrimSpace(question.SemanticSummary)); err != nil {
		return err
	}
	return s.upsertByType(context.Background(), question, string(enum.VectorTypeMistake), strings.TrimSpace(question.MistakeSummary))
}

func (s *VectorService) Delete(questionID int64) error {
	ctx := context.Background()
	vectors, err := s.vectorRepo.ListActiveByQuestionID(questionID)
	if err != nil {
		return err
	}
	if len(vectors) == 0 {
		return nil
	}

	pointIDs := make([]string, 0, len(vectors))
	for _, item := range vectors {
		pointIDs = append(pointIDs, item.VectorID)
	}
	if err := s.qdrantClient.DeletePoints(ctx, pointIDs); err != nil {
		return err
	}
	for _, item := range vectors {
		if err := s.vectorRepo.MarkDeleted(questionID, item.VectorType); err != nil {
			return err
		}
	}

	return nil
}

func (s *VectorService) Search(base model.WrongQuestion, vectorType string, limit int, useTagFilter bool) ([]SimilarSearchItem, error) {
	if limit <= 0 {
		limit = 10
	}

	text := buildSearchText(base, vectorType)
	if strings.TrimSpace(text) == "" {
		return []SimilarSearchItem{}, nil
	}

	vector, err := s.embeddingClient.Embed(context.Background(), text)
	if err != nil {
		return nil, err
	}
	if err := s.qdrantClient.EnsureCollection(context.Background(), len(vector)); err != nil {
		return nil, err
	}

	searchLimit := limit*5 + 10
	results, err := s.qdrantClient.Search(context.Background(), vector, searchLimit, buildSearchFilter(base, vectorType, useTagFilter))
	if err != nil {
		return nil, err
	}

	items := make([]SimilarSearchItem, 0, len(results))
	for _, item := range results {
		if item.QuestionID == 0 || (base.ID != 0 && item.QuestionID == base.ID) {
			continue
		}
		items = append(items, SimilarSearchItem{
			QuestionID: item.QuestionID,
			Score:      item.Score,
		})
		if len(items) >= limit {
			break
		}
	}

	return items, nil
}

func (s *VectorService) upsertByType(ctx context.Context, question model.WrongQuestion, vectorType string, text string) error {
	existing, ok, err := s.vectorRepo.GetByQuestionIDAndType(question.ID, vectorType)
	if err != nil {
		return err
	}

	if strings.TrimSpace(text) == "" {
		if ok {
			if err := s.qdrantClient.DeletePoints(ctx, []string{existing.VectorID}); err != nil {
				return err
			}
			return s.vectorRepo.MarkDeleted(question.ID, vectorType)
		}
		return nil
	}

	contentHash := hashText(text)
	payload := buildPayload(question, vectorType)

	if ok && existing.ContentHash == contentHash {
		if err := s.qdrantClient.SetPayload(ctx, []string{existing.VectorID}, payload); err != nil {
			return err
		}
		_, err := s.vectorRepo.Upsert(model.QuestionVector{
			QuestionID:     question.ID,
			VectorType:     vectorType,
			CollectionName: s.config.CollectionName,
			VectorID:       existing.VectorID,
			EmbeddingModel: s.embeddingClient.ModelName(),
			ContentHash:    contentHash,
			Status:         "active",
			CreatedAt:      existing.CreatedAt,
			UpdatedAt:      time.Now(),
		})
		return err
	}

	vector, err := s.embeddingClient.Embed(ctx, text)
	if err != nil {
		return err
	}
	if err := s.qdrantClient.EnsureCollection(ctx, len(vector)); err != nil {
		return err
	}

	vectorID := uuid.NewString()
	createdAt := time.Now()
	if ok {
		vectorID = existing.VectorID
		createdAt = existing.CreatedAt
	}
	if err := s.qdrantClient.UpsertPoint(ctx, vectorID, vector, payload); err != nil {
		return err
	}

	_, err = s.vectorRepo.Upsert(model.QuestionVector{
		QuestionID:     question.ID,
		VectorType:     vectorType,
		CollectionName: s.config.CollectionName,
		VectorID:       vectorID,
		EmbeddingModel: s.embeddingClient.ModelName(),
		ContentHash:    contentHash,
		Status:         "active",
		CreatedAt:      createdAt,
		UpdatedAt:      time.Now(),
	})
	return err
}

func buildPayload(question model.WrongQuestion, vectorType string) map[string]any {
	payload := map[string]any{
		"question_id":      question.ID,
		"user_id":          question.UserID,
		"vector_type":      vectorType,
		"subject":          question.Subject,
		"knowledge_points": append([]string{}, question.Tags.KnowledgePoints...),
		"problem_type":     append([]string{}, question.Tags.ProblemType...),
		"method":           append([]string{}, question.Tags.Method...),
		"mistake_reason":   append([]string{}, question.Tags.MistakeReason...),
		"difficulty_level": question.DifficultyLevel,
		"created_at":       question.CreatedAt.Format(time.RFC3339),
		"updated_at":       question.UpdatedAt.Format(time.RFC3339),
	}
	if strings.TrimSpace(question.Chapter) != "" {
		payload["chapter"] = question.Chapter
	}
	return payload
}

func buildSearchText(base model.WrongQuestion, vectorType string) string {
	if vectorType == string(enum.VectorTypeMistake) {
		if strings.TrimSpace(base.MistakeSummary) != "" {
			return strings.TrimSpace(base.MistakeSummary)
		}
		return strings.TrimSpace(base.WrongSolution)
	}
	if strings.TrimSpace(base.SemanticSummary) != "" {
		return strings.TrimSpace(base.SemanticSummary)
	}
	return strings.TrimSpace(base.QuestionCore)
}

func buildSearchFilter(base model.WrongQuestion, vectorType string, useTagFilter bool) map[string]any {
	must := []map[string]any{
		{
			"key": "vector_type",
			"match": map[string]any{
				"value": vectorType,
			},
		},
	}
	if strings.TrimSpace(base.Subject) != "" {
		must = append(must, map[string]any{
			"key": "subject",
			"match": map[string]any{
				"value": base.Subject,
			},
		})
	}

	if useTagFilter {
		appendAnyMatch := func(field string, values []string) {
			if len(values) == 0 {
				return
			}
			must = append(must, map[string]any{
				"key": field,
				"match": map[string]any{
					"any": values,
				},
			})
		}
		appendAnyMatch("knowledge_points", base.Tags.KnowledgePoints)
		appendAnyMatch("problem_type", base.Tags.ProblemType)
		appendAnyMatch("method", base.Tags.Method)
		if vectorType == string(enum.VectorTypeMistake) {
			appendAnyMatch("mistake_reason", base.Tags.MistakeReason)
		}
	}

	return map[string]any{"must": must}
}

func hashText(value string) string {
	sum := sha256.Sum256([]byte(value))
	return hex.EncodeToString(sum[:])
}
