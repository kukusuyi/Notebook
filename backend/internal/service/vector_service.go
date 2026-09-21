package service

import (
	"crypto/sha256"
	"encoding/hex"
	"mathnotebook/backend/internal/domain/enum"
	"mathnotebook/backend/internal/domain/model"
	"strings"
)

type VectorService struct{ Local *LocalVector }
type SimilarSearchItem struct {
	QuestionID int64
	Score      float64
}

// Triggers enqueue vector work in the same transaction as a question write.
func (s *VectorService) Upsert(question model.WrongQuestion) error { return nil }
func (s *VectorService) Delete(id int64) error {
	_, err := s.Local.DB.Exec("DELETE FROM local_vector WHERE question_id=?", id)
	return err
}
func (s *VectorService) Search(base model.WrongQuestion, kind string, limit int, filter bool) ([]SimilarSearchItem, error) {
	return s.Local.Search(base, kind, limit, filter)
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

func hashText(value string) string {
	sum := sha256.Sum256([]byte(value))
	return hex.EncodeToString(sum[:])
}
