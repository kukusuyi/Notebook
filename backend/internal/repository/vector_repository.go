package repository

import "mathnotebook/backend/internal/domain/model"

type VectorRepository interface {
	Upsert(vector model.QuestionVector) (model.QuestionVector, error)
	GetByQuestionIDAndType(questionID int64, vectorType string) (model.QuestionVector, bool, error)
	ListActiveByQuestionID(questionID int64) ([]model.QuestionVector, error)
	MarkDeleted(questionID int64, vectorType string) error
}
