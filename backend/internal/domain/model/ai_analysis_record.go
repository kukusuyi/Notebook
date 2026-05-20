package model

import "time"

type AIAnalysisRecord struct {
	ID                int64
	UserID            int64
	QuestionID        *int64
	ProviderName      string
	ModelName         string
	AnalysisType      string
	InputQuestionJSON string
	OutputTagsJSON    string
	SemanticSummary   string
	MistakeSummary    string
	Status            string
	ErrorMessage      string
	CreatedAt         time.Time
}
