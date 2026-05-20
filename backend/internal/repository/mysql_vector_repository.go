package repository

import (
	"database/sql"

	"mathnotebook/backend/internal/domain/model"
)

type MySQLVectorRepository struct {
	db *sql.DB
}

func NewMySQLVectorRepository(db *sql.DB) *MySQLVectorRepository {
	return &MySQLVectorRepository{db: db}
}

func (r *MySQLVectorRepository) Upsert(vector model.QuestionVector) (model.QuestionVector, error) {
	_, ok, err := r.GetByQuestionIDAndType(vector.QuestionID, vector.VectorType)
	if err != nil {
		return model.QuestionVector{}, err
	}

	if ok {
		_, err = r.db.Exec(
			`UPDATE question_vector
			SET collection_name = ?,
			    vector_id = ?,
			    embedding_model = ?,
			    content_hash = ?,
			    status = ?,
			    updated_at = CURRENT_TIMESTAMP
			WHERE question_id = ? AND vector_type = ? AND status = 'active'`,
			vector.CollectionName,
			vector.VectorID,
			vector.EmbeddingModel,
			vector.ContentHash,
			vector.Status,
			vector.QuestionID,
			vector.VectorType,
		)
		if err != nil {
			return model.QuestionVector{}, err
		}
		updated, _, getErr := r.GetByQuestionIDAndType(vector.QuestionID, vector.VectorType)
		return updated, getErr
	}

	_, err = r.db.Exec(
		`INSERT INTO question_vector
		(question_id, vector_type, collection_name, vector_id, embedding_model, content_hash, status, created_at, updated_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		vector.QuestionID,
		vector.VectorType,
		vector.CollectionName,
		vector.VectorID,
		vector.EmbeddingModel,
		vector.ContentHash,
		vector.Status,
		vector.CreatedAt,
		vector.UpdatedAt,
	)
	if err != nil {
		return model.QuestionVector{}, err
	}

	created, _, getErr := r.GetByQuestionIDAndType(vector.QuestionID, vector.VectorType)
	return created, getErr
}

func (r *MySQLVectorRepository) GetByQuestionIDAndType(questionID int64, vectorType string) (model.QuestionVector, bool, error) {
	row := r.db.QueryRow(
		`SELECT question_id, vector_type, collection_name, vector_id, embedding_model, content_hash, status, created_at, updated_at
		FROM question_vector
		WHERE question_id = ? AND vector_type = ? AND status = 'active'
		ORDER BY id DESC
		LIMIT 1`,
		questionID,
		vectorType,
	)
	item, err := scanQuestionVector(row)
	if err == sql.ErrNoRows {
		return model.QuestionVector{}, false, nil
	}
	if err != nil {
		return model.QuestionVector{}, false, err
	}

	return item, true, nil
}

func (r *MySQLVectorRepository) ListActiveByQuestionID(questionID int64) ([]model.QuestionVector, error) {
	rows, err := r.db.Query(
		`SELECT question_id, vector_type, collection_name, vector_id, embedding_model, content_hash, status, created_at, updated_at
		FROM question_vector
		WHERE question_id = ? AND status = 'active'
		ORDER BY id ASC`,
		questionID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := make([]model.QuestionVector, 0)
	for rows.Next() {
		item, scanErr := scanQuestionVector(rows)
		if scanErr != nil {
			return nil, scanErr
		}
		items = append(items, item)
	}

	return items, rows.Err()
}

func (r *MySQLVectorRepository) MarkDeleted(questionID int64, vectorType string) error {
	_, err := r.db.Exec(
		`UPDATE question_vector
		SET status = 'deleted',
		    updated_at = CURRENT_TIMESTAMP
		WHERE question_id = ? AND vector_type = ? AND status = 'active'`,
		questionID,
		vectorType,
	)
	return err
}
