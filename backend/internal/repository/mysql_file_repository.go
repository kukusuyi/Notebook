package repository

import (
	"database/sql"

	"mathnotebook/backend/internal/domain/model"
)

type MySQLFileRepository struct {
	db *sql.DB
}

func NewMySQLFileRepository(db *sql.DB) *MySQLFileRepository {
	return &MySQLFileRepository{db: db}
}

func (r *MySQLFileRepository) Create(record model.FileRecord) (model.FileRecord, error) {
	result, err := r.db.Exec(
		`INSERT INTO file_record
		(user_id, question_id, storage_provider, bucket_name, object_key, file_name, file_url, file_size, mime_type, file_type, created_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		record.UserID,
		nullableInt64Value(record.QuestionID),
		record.StorageProvider,
		record.BucketName,
		record.ObjectKey,
		record.FileName,
		record.FileURL,
		record.FileSize,
		record.MIMEType,
		record.FileType,
		record.CreatedAt,
	)
	if err != nil {
		return model.FileRecord{}, err
	}

	id, err := result.LastInsertId()
	if err != nil {
		return model.FileRecord{}, err
	}

	record.ID = id
	return record, nil
}

func (r *MySQLFileRepository) GetByID(id int64) (model.FileRecord, bool) {
	row := r.db.QueryRow(
		`SELECT id, user_id, question_id, storage_provider, bucket_name, object_key, file_name, file_url, file_size, mime_type, file_type, created_at
		FROM file_record
		WHERE id = ?`,
		id,
	)
	item, err := scanFileRecord(row)
	if err == sql.ErrNoRows {
		return model.FileRecord{}, false
	}
	if err != nil {
		return model.FileRecord{}, false
	}

	return item, true
}

func (r *MySQLFileRepository) BindQuestion(imageID, questionID int64) error {
	tx, err := r.db.Begin()
	if err != nil {
		return err
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
		}
	}()

	if _, err = tx.Exec(
		`UPDATE file_record
		SET question_id = NULL
		WHERE question_id = ? AND id <> ?`,
		questionID,
		imageID,
	); err != nil {
		return err
	}

	if _, err = tx.Exec(
		`UPDATE file_record
		SET question_id = ?
		WHERE id = ?`,
		questionID,
		imageID,
	); err != nil {
		return err
	}

	err = tx.Commit()
	return err
}
