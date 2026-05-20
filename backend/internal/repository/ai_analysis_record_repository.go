package repository

import (
	"database/sql"

	"mathnotebook/backend/internal/domain/model"
)

type AIAnalysisRecordRepository interface {
	Create(record model.AIAnalysisRecord) (model.AIAnalysisRecord, error)
}

type MySQLAIAnalysisRecordRepository struct {
	db *sql.DB
}

func NewMySQLAIAnalysisRecordRepository(db *sql.DB) *MySQLAIAnalysisRecordRepository {
	return &MySQLAIAnalysisRecordRepository{db: db}
}

func (r *MySQLAIAnalysisRecordRepository) Create(record model.AIAnalysisRecord) (model.AIAnalysisRecord, error) {
	result, err := r.db.Exec(
		`INSERT INTO ai_analysis_record
		(user_id, question_id, provider_name, model_name, analysis_type, input_question_json, output_tags_json, semantic_summary, mistake_summary, status, error_message)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		record.UserID,
		nullableInt64(record.QuestionID),
		record.ProviderName,
		record.ModelName,
		record.AnalysisType,
		record.InputQuestionJSON,
		nullableJSON(record.OutputTagsJSON),
		nullableString(record.SemanticSummary),
		nullableString(record.MistakeSummary),
		record.Status,
		nullableString(record.ErrorMessage),
	)
	if err != nil {
		return model.AIAnalysisRecord{}, err
	}

	recordID, err := result.LastInsertId()
	if err != nil {
		return model.AIAnalysisRecord{}, err
	}

	record.ID = recordID
	return record, nil
}

func nullableString(value string) any {
	if value == "" {
		return nil
	}
	return value
}

func nullableJSON(value string) any {
	if value == "" {
		return nil
	}
	return value
}

func nullableInt64(value *int64) any {
	if value == nil {
		return nil
	}
	return *value
}
