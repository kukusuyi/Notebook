package sqlite

import (
	"database/sql"
	_ "embed"
	"fmt"
	_ "modernc.org/sqlite"
	"net/url"
	"path/filepath"
	"strings"
	"time"
)

//go:embed schema.sql
var schema string

const Version = 1

func Open(dir string) (*sql.DB, error) {
	path := filepath.Join(dir, "notebook.db")
	u := databaseURL(path)
	db, err := sql.Open("sqlite", u.String()+"?_pragma=foreign_keys(1)&_pragma=busy_timeout(5000)&_pragma=journal_mode(WAL)&_time_format=sqlite")
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(1)
	db.SetMaxIdleConns(1)
	if err = migrate(db, dir); err != nil {
		db.Close()
		return nil, err
	}
	return db, nil
}
func migrate(db *sql.DB, dir string) error {
	var version int
	if err := db.QueryRow("PRAGMA user_version").Scan(&version); err != nil {
		return err
	}
	if version > Version {
		return fmt.Errorf("database version %d is newer than supported %d", version, Version)
	}
	if version == Version {
		return nil
	}
	if version > 0 {
		path := filepath.Join(dir, fmt.Sprintf("before-upgrade-%d.db", time.Now().UnixNano()))
		if _, err := db.Exec("VACUUM INTO '" + strings.ReplaceAll(path, "'", "''") + "'"); err != nil {
			return err
		}
	}
	tx, err := db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if _, err = tx.Exec(schema); err != nil {
		return err
	}
	if _, err = tx.Exec(fmt.Sprintf("PRAGMA user_version=%d", Version)); err != nil {
		return err
	}
	return tx.Commit()
}

// A Windows drive must be in the URI path, never parsed as a hostname.
func databaseURL(path string) url.URL {
	path = filepath.ToSlash(path)
	if len(path) > 1 && path[1] == ':' {
		path = "/" + path
	}
	return url.URL{Scheme: "file", Path: path}
}
