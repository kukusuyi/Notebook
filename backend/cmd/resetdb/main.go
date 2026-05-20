package main

import (
	"database/sql"
	"flag"
	"fmt"
	"log"
	"slices"
	"strings"

	"mathnotebook/backend/internal/config"
	"mathnotebook/backend/internal/infra/mysql"
)

func main() {
	if err := run(); err != nil {
		log.Fatal(err)
	}
}

func run() error {
	confirmed := flag.Bool("yes", false, "confirm wiping all MySQL tables in the configured database")
	leaveEmpty := flag.Bool("empty", false, "leave the database fully empty without recreating the default user")
	allowProduction := flag.Bool("allow-production", false, "allow running when app.env=production")
	flag.Parse()

	cfg := config.Load()
	if !*confirmed {
		return fmt.Errorf("refusing to wipe database %q: rerun with --yes to confirm", cfg.DB.Name)
	}
	if strings.EqualFold(cfg.App.Env, "production") && !*allowProduction {
		return fmt.Errorf("refusing to wipe database %q because app.env=production; rerun with --allow-production if you really intend to do this", cfg.DB.Name)
	}
	if strings.TrimSpace(cfg.DB.Name) == "" {
		return fmt.Errorf("db.name is empty; refusing to continue")
	}

	db, err := mysql.Open(cfg.DB)
	if err != nil {
		return fmt.Errorf("open mysql: %w", err)
	}
	defer db.Close()

	tables, err := loadTables(db, cfg.DB.Name)
	if err != nil {
		return fmt.Errorf("load table list: %w", err)
	}
	if len(tables) == 0 {
		log.Printf("database %q has no tables to reset", cfg.DB.Name)
		return nil
	}

	log.Printf("wiping %d tables from mysql database %q", len(tables), cfg.DB.Name)
	if err := exec(db, "SET FOREIGN_KEY_CHECKS = 0"); err != nil {
		return fmt.Errorf("disable foreign key checks: %w", err)
	}
	defer func() {
		if err := exec(db, "SET FOREIGN_KEY_CHECKS = 1"); err != nil {
			log.Printf("re-enable foreign key checks failed: %v", err)
		}
	}()

	for _, table := range tables {
		statement := fmt.Sprintf("TRUNCATE TABLE %s", quoteIdentifier(table))
		if err := exec(db, statement); err != nil {
			return fmt.Errorf("truncate table %q: %w", table, err)
		}
		log.Printf("truncated %s", table)
	}

	if err := exec(db, "SET FOREIGN_KEY_CHECKS = 1"); err != nil {
		return fmt.Errorf("re-enable foreign key checks: %w", err)
	}

	if *leaveEmpty {
		log.Printf("database %q is now empty", cfg.DB.Name)
		return nil
	}

	if err := ensureDefaultUser(db, cfg.DefaultUser); err != nil {
		return fmt.Errorf("recreate default user: %w", err)
	}
	log.Printf("database %q reset complete; default user %q recreated with id=%d", cfg.DB.Name, cfg.DefaultUser.Username, cfg.DefaultUser.ID)
	return nil
}

func loadTables(db *sql.DB, schema string) ([]string, error) {
	rows, err := db.Query(`
		SELECT table_name
		FROM information_schema.tables
		WHERE table_schema = ?
		  AND table_type = 'BASE TABLE'
	`, schema)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var tables []string
	for rows.Next() {
		var table string
		if err := rows.Scan(&table); err != nil {
			return nil, err
		}
		tables = append(tables, table)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	slices.Sort(tables)
	return tables, nil
}

func ensureDefaultUser(db *sql.DB, cfg config.DefaultUserConfig) error {
	if cfg.ID <= 0 {
		return fmt.Errorf("default user id must be positive")
	}

	_, err := db.Exec(
		`INSERT INTO user (id, username, email, password_hash, role)
		VALUES (?, ?, ?, NULL, 'user')
		ON DUPLICATE KEY UPDATE
			username = VALUES(username),
			email = VALUES(email)`,
		cfg.ID,
		cfg.Username,
		cfg.Email,
	)
	return err
}

func quoteIdentifier(identifier string) string {
	return "`" + strings.ReplaceAll(identifier, "`", "``") + "`"
}

func exec(db *sql.DB, statement string) error {
	_, err := db.Exec(statement)
	return err
}
