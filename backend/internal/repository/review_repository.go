package repository

import (
	"database/sql"
	"github.com/kukusuyi/Questrace/backend/internal/domain/model"
)

type ReviewRepository struct{ DB *sql.DB }

func (r ReviewRepository) History(uid int64) ([]model.ReviewRecord, error) {
	rows, err := r.DB.Query(`SELECT question_id,review_result,mastery_after,coalesce(note,''),reviewed_at,coalesce(next_due_at,0) FROM review_record WHERE user_id=? ORDER BY id DESC LIMIT 100`, uid)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []model.ReviewRecord{}
	for rows.Next() {
		var item model.ReviewRecord
		if err = rows.Scan(&item.QuestionID, &item.Result, &item.MasteryStatus, &item.Note, &item.ReviewedAt, &item.DueAt); err != nil {
			return nil, err
		}
		out = append(out, item)
	}
	return out, rows.Err()
}
