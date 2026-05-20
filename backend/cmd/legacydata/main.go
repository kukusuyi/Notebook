package main

import (
	"database/sql"
	"flag"
	"fmt"
	"log"
	"strings"

	"mathnotebook/backend/internal/config"
	mysqlinfra "mathnotebook/backend/internal/infra/mysql"
)

func main() {
	if err := run(); err != nil {
		log.Fatal(err)
	}
}

func run() error {
	inspectOnly := flag.Bool("inspect", false, "print user/data ownership summary")
	targetUsername := flag.String("target-username", "", "move legacy default-user data to this username")
	sourceUserID := flag.Int64("source-user-id", 1, "legacy source user id, usually the configured default user id")
	confirmed := flag.Bool("yes", false, "confirm running the migration")
	allowProduction := flag.Bool("allow-production", false, "allow running when app.env=production")
	flag.Parse()

	cfg := config.Load()
	if *sourceUserID <= 0 {
		*sourceUserID = cfg.DefaultUser.ID
	}

	if strings.EqualFold(cfg.App.Env, "production") && !*allowProduction {
		return fmt.Errorf("refusing to run because app.env=production; rerun with --allow-production if you really intend this")
	}

	db, err := mysqlinfra.Open(cfg.DB)
	if err != nil {
		return fmt.Errorf("open mysql: %w", err)
	}
	defer db.Close()

	if *inspectOnly || strings.TrimSpace(*targetUsername) == "" {
		return inspect(db)
	}
	if !*confirmed {
		return fmt.Errorf("refusing to migrate legacy data without --yes confirmation")
	}

	return migrateLegacyData(db, *sourceUserID, strings.TrimSpace(*targetUsername))
}

func inspect(db *sql.DB) error {
	fmt.Println("USERS")
	rows, err := db.Query(`SELECT id, username, email FROM user ORDER BY id`)
	if err != nil {
		return err
	}
	defer rows.Close()

	for rows.Next() {
		var id int64
		var username string
		var email sql.NullString
		if err := rows.Scan(&id, &username, &email); err != nil {
			return err
		}
		fmt.Printf("%d\t%s\t%s\n", id, username, email.String)
	}
	if err := rows.Err(); err != nil {
		return err
	}

	fmt.Println("QUESTION_COUNTS")
	if err := printCountRows(db, `SELECT user_id, COUNT(*) FROM wrong_question WHERE is_deleted = 0 GROUP BY user_id ORDER BY user_id`); err != nil {
		return err
	}
	fmt.Println("TAG_COUNTS")
	if err := printCountRows(db, `SELECT user_id, COUNT(*) FROM tag WHERE is_active = 1 GROUP BY user_id ORDER BY user_id`); err != nil {
		return err
	}
	fmt.Println("FILE_COUNTS")
	return printCountRows(db, `SELECT user_id, COUNT(*) FROM file_record GROUP BY user_id ORDER BY user_id`)
}

func printCountRows(db *sql.DB, query string) error {
	rows, err := db.Query(query)
	if err != nil {
		return err
	}
	defer rows.Close()

	for rows.Next() {
		var userID int64
		var count int
		if err := rows.Scan(&userID, &count); err != nil {
			return err
		}
		fmt.Printf("%d\t%d\n", userID, count)
	}
	return rows.Err()
}

func migrateLegacyData(db *sql.DB, sourceUserID int64, targetUsername string) error {
	targetUserID, err := getUserIDByUsername(db, targetUsername)
	if err != nil {
		return err
	}
	if targetUserID == sourceUserID {
		return fmt.Errorf("target user %q is already source user id=%d", targetUsername, sourceUserID)
	}

	tx, err := db.Begin()
	if err != nil {
		return err
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
		}
	}()

	if err = updateOwnership(tx, "wrong_question", sourceUserID, targetUserID); err != nil {
		return fmt.Errorf("migrate wrong_question: %w", err)
	}
	if err = updateOwnership(tx, "file_record", sourceUserID, targetUserID); err != nil {
		return fmt.Errorf("migrate file_record: %w", err)
	}
	if err = updateOwnership(tx, "ocr_record", sourceUserID, targetUserID); err != nil {
		return fmt.Errorf("migrate ocr_record: %w", err)
	}
	if err = updateOwnership(tx, "ai_analysis_record", sourceUserID, targetUserID); err != nil {
		return fmt.Errorf("migrate ai_analysis_record: %w", err)
	}
	if err = updateOwnership(tx, "review_record", sourceUserID, targetUserID); err != nil {
		return fmt.Errorf("migrate review_record: %w", err)
	}
	if err = migrateTags(tx, sourceUserID, targetUserID); err != nil {
		return fmt.Errorf("migrate tags: %w", err)
	}
	if err = recalcTagUsage(tx, sourceUserID); err != nil {
		return fmt.Errorf("recalc source tag usage: %w", err)
	}
	if err = recalcTagUsage(tx, targetUserID); err != nil {
		return fmt.Errorf("recalc target tag usage: %w", err)
	}

	if err = tx.Commit(); err != nil {
		return err
	}

	fmt.Printf("legacy data migrated from user_id=%d to username=%s (user_id=%d)\n", sourceUserID, targetUsername, targetUserID)
	return nil
}

func getUserIDByUsername(db *sql.DB, username string) (int64, error) {
	var userID int64
	err := db.QueryRow(`SELECT id FROM user WHERE username = ?`, username).Scan(&userID)
	if err == sql.ErrNoRows {
		return 0, fmt.Errorf("target username %q does not exist", username)
	}
	if err != nil {
		return 0, err
	}
	return userID, nil
}

func updateOwnership(tx *sql.Tx, table string, sourceUserID, targetUserID int64) error {
	statement := fmt.Sprintf(`UPDATE %s SET user_id = ? WHERE user_id = ?`, quoteIdentifier(table))
	_, err := tx.Exec(statement, targetUserID, sourceUserID)
	return err
}

func migrateTags(tx *sql.Tx, sourceUserID, targetUserID int64) error {
	rows, err := tx.Query(`
		SELECT id, tag_name, tag_type
		FROM tag
		WHERE user_id = ?
		ORDER BY id ASC
	`, sourceUserID)
	if err != nil {
		return err
	}
	defer rows.Close()

	type tagRow struct {
		id      int64
		tagName string
		tagType string
	}
	var tags []tagRow
	for rows.Next() {
		var item tagRow
		if err := rows.Scan(&item.id, &item.tagName, &item.tagType); err != nil {
			return err
		}
		tags = append(tags, item)
	}
	if err := rows.Err(); err != nil {
		return err
	}

	for _, item := range tags {
		var targetTagID int64
		err := tx.QueryRow(`
			SELECT id
			FROM tag
			WHERE user_id = ? AND tag_type = ? AND tag_name = ?
		`, targetUserID, item.tagType, item.tagName).Scan(&targetTagID)

		switch {
		case err == sql.ErrNoRows:
			if _, err := tx.Exec(`UPDATE tag SET user_id = ? WHERE id = ? AND user_id = ?`, targetUserID, item.id, sourceUserID); err != nil {
				return err
			}
		case err != nil:
			return err
		default:
			if _, err := tx.Exec(`
				DELETE wqt_source
				FROM wrong_question_tag wqt_source
				INNER JOIN wrong_question q ON q.id = wqt_source.question_id
				INNER JOIN wrong_question_tag wqt_target
					ON wqt_target.question_id = wqt_source.question_id
					AND wqt_target.tag_id = ?
				WHERE wqt_source.tag_id = ?
				  AND q.user_id = ?
			`, targetTagID, item.id, targetUserID); err != nil {
				return err
			}
			if _, err := tx.Exec(`
				UPDATE wrong_question_tag wqt
				INNER JOIN wrong_question q ON q.id = wqt.question_id
				SET wqt.tag_id = ?
				WHERE wqt.tag_id = ?
				  AND q.user_id = ?
			`, targetTagID, item.id, targetUserID); err != nil {
				return err
			}
			if _, err := tx.Exec(`DELETE FROM tag WHERE id = ? AND user_id = ?`, item.id, sourceUserID); err != nil {
				return err
			}
		}
	}

	return nil
}

func recalcTagUsage(tx *sql.Tx, userID int64) error {
	_, err := tx.Exec(`
		UPDATE tag t
		SET usage_count = (
			SELECT COUNT(*)
			FROM wrong_question_tag wqt
			WHERE wqt.tag_id = t.id
		)
		WHERE t.user_id = ?
	`, userID)
	return err
}

func quoteIdentifier(identifier string) string {
	return "`" + strings.ReplaceAll(identifier, "`", "``") + "`"
}
