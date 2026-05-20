package repository

import (
	"database/sql"
	"fmt"
	"strings"
	"time"

	"mathnotebook/backend/internal/domain/model"
)

type MySQLQuestionRepository struct {
	db *sql.DB
}

func NewMySQLQuestionRepository(db *sql.DB) *MySQLQuestionRepository {
	return &MySQLQuestionRepository{db: db}
}

func (r *MySQLQuestionRepository) Create(question model.WrongQuestion) (model.WrongQuestion, error) {
	tx, err := r.db.Begin()
	if err != nil {
		return model.WrongQuestion{}, err
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
		}
	}()

	result, err := tx.Exec(
		`INSERT INTO wrong_question
		(user_id, subject, chapter, question_core, standard_solution, wrong_solution, semantic_summary, mistake_summary, difficulty_level, mastery_status, source_type, source_image_id, source_image_url, is_deleted, deleted_at, created_at, updated_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		question.UserID,
		question.Subject,
		nullableStringValue(question.Chapter),
		question.QuestionCore,
		nullableStringValue(question.StandardSolution),
		nullableStringValue(question.WrongSolution),
		question.SemanticSummary,
		nullableStringValue(question.MistakeSummary),
		nullableDifficulty(question.DifficultyLevel),
		question.MasteryStatus,
		question.SourceType,
		nullableInt64Value(question.SourceImageID),
		nullableStringValue(question.SourceImageURL),
		question.IsDeleted,
		nullableTimeValue(question.DeletedAt),
		question.CreatedAt,
		question.UpdatedAt,
	)
	if err != nil {
		return model.WrongQuestion{}, err
	}

	questionID, err := result.LastInsertId()
	if err != nil {
		return model.WrongQuestion{}, err
	}

	if err = r.replaceQuestionTags(tx, questionID, question.UserID, question.Tags); err != nil {
		return model.WrongQuestion{}, err
	}

	if err = tx.Commit(); err != nil {
		return model.WrongQuestion{}, err
	}

	return r.mustGetByID(questionID)
}

func (r *MySQLQuestionRepository) Update(question model.WrongQuestion) (model.WrongQuestion, error) {
	tx, err := r.db.Begin()
	if err != nil {
		return model.WrongQuestion{}, err
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
		}
	}()

	_, err = tx.Exec(
		`UPDATE wrong_question
		SET subject = ?,
		    chapter = ?,
		    question_core = ?,
		    standard_solution = ?,
		    wrong_solution = ?,
		    semantic_summary = ?,
		    mistake_summary = ?,
		    difficulty_level = ?,
		    mastery_status = ?,
		    source_image_id = ?,
		    source_image_url = ?,
		    updated_at = ?
		WHERE id = ?`,
		question.Subject,
		nullableStringValue(question.Chapter),
		question.QuestionCore,
		nullableStringValue(question.StandardSolution),
		nullableStringValue(question.WrongSolution),
		question.SemanticSummary,
		nullableStringValue(question.MistakeSummary),
		nullableDifficulty(question.DifficultyLevel),
		question.MasteryStatus,
		nullableInt64Value(question.SourceImageID),
		nullableStringValue(question.SourceImageURL),
		question.UpdatedAt,
		question.ID,
	)
	if err != nil {
		return model.WrongQuestion{}, err
	}

	if err = r.replaceQuestionTags(tx, question.ID, question.UserID, question.Tags); err != nil {
		return model.WrongQuestion{}, err
	}

	if err = tx.Commit(); err != nil {
		return model.WrongQuestion{}, err
	}

	return r.mustGetByID(question.ID)
}

func (r *MySQLQuestionRepository) GetByID(id int64) (model.WrongQuestion, bool) {
	row := r.db.QueryRow(
		`SELECT id, user_id, subject, chapter, question_core, standard_solution, wrong_solution, semantic_summary, mistake_summary, difficulty_level, mastery_status, source_type, source_image_id, source_image_url, is_deleted, deleted_at, created_at, updated_at
		FROM wrong_question
		WHERE id = ?`,
		id,
	)
	item, err := scanQuestion(row)
	if err == sql.ErrNoRows {
		return model.WrongQuestion{}, false
	}
	if err != nil {
		return model.WrongQuestion{}, false
	}

	tagMap, err := r.loadTagsByQuestionIDs([]int64{id})
	if err == nil {
		item.Tags = tagMap[id]
	}

	return item, true
}

func (r *MySQLQuestionRepository) List(filter QuestionFilter) ([]model.WrongQuestion, int, error) {
	whereSQL, args := buildQuestionFilterSQL(filter)

	countQuery := "SELECT COUNT(*) FROM wrong_question q" + whereSQL
	var total int
	if err := r.db.QueryRow(countQuery, args...).Scan(&total); err != nil {
		return nil, 0, err
	}
	if total == 0 {
		return []model.WrongQuestion{}, 0, nil
	}

	query := `
SELECT q.id, q.user_id, q.subject, q.chapter, q.question_core, q.standard_solution, q.wrong_solution, q.semantic_summary, q.mistake_summary, q.difficulty_level, q.mastery_status, q.source_type, q.source_image_id, q.source_image_url, q.is_deleted, q.deleted_at, q.created_at, q.updated_at
FROM wrong_question q` + whereSQL + `
ORDER BY q.created_at DESC, q.id DESC
LIMIT ? OFFSET ?`
	queryArgs := append(append([]any{}, args...), filter.PageSize, (filter.Page-1)*filter.PageSize)

	rows, err := r.db.Query(query, queryArgs...)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	items := make([]model.WrongQuestion, 0)
	questionIDs := make([]int64, 0)
	for rows.Next() {
		item, scanErr := scanQuestion(rows)
		if scanErr != nil {
			return nil, 0, scanErr
		}
		items = append(items, item)
		questionIDs = append(questionIDs, item.ID)
	}
	if err = rows.Err(); err != nil {
		return nil, 0, err
	}

	tagMap, err := r.loadTagsByQuestionIDs(questionIDs)
	if err != nil {
		return nil, 0, err
	}
	for i := range items {
		items[i].Tags = tagMap[items[i].ID]
	}

	return items, total, nil
}

func (r *MySQLQuestionRepository) DashboardMetrics(userID int64, now time.Time) (QuestionDashboardMetrics, error) {
	start := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	end := start.Add(24 * time.Hour)

	metrics := QuestionDashboardMetrics{
		MasteryStatusMap: make(map[string]int),
		SourceTypeMap:    make(map[string]int),
	}

	if err := r.db.QueryRow(
		`SELECT COUNT(*),
		        COALESCE(SUM(CASE WHEN created_at >= ? AND created_at < ? THEN 1 ELSE 0 END), 0),
		        COALESCE(SUM(CASE WHEN mastery_status = 'unmastered' THEN 1 ELSE 0 END), 0),
		        COALESCE(SUM(CASE WHEN source_image_id IS NOT NULL OR (source_image_url IS NOT NULL AND source_image_url <> '') THEN 1 ELSE 0 END), 0)
		FROM wrong_question
		WHERE is_deleted = 0 AND user_id = ?`,
		start,
		end,
		userID,
	).Scan(
		&metrics.TotalQuestions,
		&metrics.TodayAdded,
		&metrics.UnmasteredCount,
		&metrics.ImageBoundCount,
	); err != nil {
		return QuestionDashboardMetrics{}, err
	}

	masteryRows, err := r.db.Query(
		`SELECT mastery_status, COUNT(*)
		FROM wrong_question
		WHERE is_deleted = 0 AND user_id = ?
		GROUP BY mastery_status`,
		userID,
	)
	if err != nil {
		return QuestionDashboardMetrics{}, err
	}
	defer masteryRows.Close()

	for masteryRows.Next() {
		var masteryStatus string
		var count int
		if scanErr := masteryRows.Scan(&masteryStatus, &count); scanErr != nil {
			return QuestionDashboardMetrics{}, scanErr
		}
		metrics.MasteryStatusMap[masteryStatus] = count
	}
	if err = masteryRows.Err(); err != nil {
		return QuestionDashboardMetrics{}, err
	}

	sourceRows, err := r.db.Query(
		`SELECT source_type, COUNT(*)
		FROM wrong_question
		WHERE is_deleted = 0 AND user_id = ?
		GROUP BY source_type`,
		userID,
	)
	if err != nil {
		return QuestionDashboardMetrics{}, err
	}
	defer sourceRows.Close()

	for sourceRows.Next() {
		var sourceType string
		var count int
		if scanErr := sourceRows.Scan(&sourceType, &count); scanErr != nil {
			return QuestionDashboardMetrics{}, scanErr
		}
		metrics.SourceTypeMap[sourceType] = count
	}

	return metrics, sourceRows.Err()
}

func (r *MySQLQuestionRepository) SoftDelete(id int64, deletedAt time.Time) (model.WrongQuestion, bool, error) {
	result, err := r.db.Exec(
		`UPDATE wrong_question
		SET is_deleted = 1,
		    deleted_at = ?,
		    updated_at = ?
		WHERE id = ?`,
		deletedAt,
		deletedAt,
		id,
	)
	if err != nil {
		return model.WrongQuestion{}, false, err
	}

	affected, err := result.RowsAffected()
	if err != nil {
		return model.WrongQuestion{}, false, err
	}
	if affected == 0 {
		return model.WrongQuestion{}, false, nil
	}

	item, err := r.mustGetByID(id)
	if err != nil {
		return model.WrongQuestion{}, false, err
	}

	return item, true, nil
}

func (r *MySQLQuestionRepository) mustGetByID(id int64) (model.WrongQuestion, error) {
	item, ok := r.GetByID(id)
	if !ok {
		return model.WrongQuestion{}, sql.ErrNoRows
	}
	return item, nil
}

func (r *MySQLQuestionRepository) replaceQuestionTags(tx *sql.Tx, questionID, userID int64, tags model.TagCollections) error {
	if _, err := tx.Exec("DELETE FROM wrong_question_tag WHERE question_id = ?", questionID); err != nil {
		return err
	}

	for _, item := range collectTypedTagRecords(tags) {
		result, err := tx.Exec(
			`INSERT INTO wrong_question_tag (question_id, tag_id, tag_type)
			SELECT ?, id, tag_type
			FROM tag
			WHERE user_id = ? AND tag_type = ? AND tag_name = ? AND is_active = 1`,
			questionID,
			userID,
			item.TagType,
			item.Name,
		)
		if err != nil {
			return err
		}
		affected, err := result.RowsAffected()
		if err != nil {
			return err
		}
		if affected == 0 {
			return formatMissingTagError(item.TagType, item.Name)
		}
	}

	return nil
}

func (r *MySQLQuestionRepository) loadTagsByQuestionIDs(questionIDs []int64) (map[int64]model.TagCollections, error) {
	result := make(map[int64]model.TagCollections, len(questionIDs))
	if len(questionIDs) == 0 {
		return result, nil
	}

	query := fmt.Sprintf(
		`SELECT wqt.question_id, t.tag_type, t.tag_name
		FROM wrong_question_tag wqt
		INNER JOIN tag t ON t.id = wqt.tag_id
		WHERE t.is_active = 1 AND wqt.question_id IN (%s)
		ORDER BY wqt.id ASC`,
		buildInt64InClause(questionIDs),
	)
	args := make([]any, 0, len(questionIDs))
	for _, id := range questionIDs {
		args = append(args, id)
	}

	rows, err := r.db.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	for rows.Next() {
		var questionID int64
		var tagType string
		var tagName string
		if scanErr := rows.Scan(&questionID, &tagType, &tagName); scanErr != nil {
			return nil, scanErr
		}

		groups := result[questionID]
		switch tagType {
		case "knowledge_point":
			groups.KnowledgePoints = append(groups.KnowledgePoints, tagName)
		case "problem_type":
			groups.ProblemType = append(groups.ProblemType, tagName)
		case "method":
			groups.Method = append(groups.Method, tagName)
		case "mistake_reason":
			groups.MistakeReason = append(groups.MistakeReason, tagName)
		}
		result[questionID] = groups
	}

	return result, rows.Err()
}

func buildQuestionFilterSQL(filter QuestionFilter) (string, []any) {
	conditions := []string{"q.is_deleted = 0"}
	args := make([]any, 0)

	if filter.UserID > 0 {
		conditions = append(conditions, "q.user_id = ?")
		args = append(args, filter.UserID)
	}

	if strings.TrimSpace(filter.Subject) != "" {
		conditions = append(conditions, "q.subject = ?")
		args = append(args, strings.TrimSpace(filter.Subject))
	}
	if strings.TrimSpace(filter.Chapter) != "" {
		conditions = append(conditions, "q.chapter LIKE ?")
		args = append(args, "%"+strings.TrimSpace(filter.Chapter)+"%")
	}
	if strings.TrimSpace(filter.Keyword) != "" {
		conditions = append(conditions, "(q.question_core LIKE ? OR q.semantic_summary LIKE ? OR q.wrong_solution LIKE ?)")
		keyword := "%" + strings.TrimSpace(filter.Keyword) + "%"
		args = append(args, keyword, keyword, keyword)
	}
	if strings.TrimSpace(filter.MasteryStatus) != "" {
		conditions = append(conditions, "q.mastery_status = ?")
		args = append(args, filter.MasteryStatus)
	}
	if filter.DifficultyLevel > 0 {
		conditions = append(conditions, "q.difficulty_level = ?")
		args = append(args, filter.DifficultyLevel)
	}
	if strings.TrimSpace(filter.SourceType) != "" {
		conditions = append(conditions, "q.source_type = ?")
		args = append(args, filter.SourceType)
	}
	if len(filter.TagNames) > 0 {
		conditions = append(conditions, fmt.Sprintf(
			`EXISTS (
				SELECT 1
				FROM wrong_question_tag wqt
				INNER JOIN tag t ON t.id = wqt.tag_id
				WHERE wqt.question_id = q.id
				  AND t.is_active = 1
				  AND t.tag_name IN (%s)
			)`,
			buildInClause(filter.TagNames),
		))
		for _, name := range filter.TagNames {
			args = append(args, name)
		}
	}

	return " WHERE " + strings.Join(conditions, " AND "), args
}

func nullableDifficulty(value int) any {
	if value <= 0 {
		return nil
	}
	return value
}
