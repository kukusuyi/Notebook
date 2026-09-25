package sqlite

import (
	"database/sql"
	"net/url"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestDatabaseURL(t *testing.T) {
	for _, path := range []string{"C:/Users/中文 data/questrace.db", "/tmp/中文 data/questrace.db"} {
		uri := databaseURL(path)
		parsed, err := url.Parse(uri.String())
		if err != nil || parsed.Host != "" || parsed.Path[0] != '/' {
			t.Fatalf("invalid SQLite URI: %s", uri.String())
		}
	}
}

func TestResolvePath(t *testing.T) {
	touch := func(t *testing.T, path string) {
		t.Helper()
		if err := os.WriteFile(path, []byte("x"), 0600); err != nil {
			t.Fatal(err)
		}
	}

	// A fresh directory gets the new file name.
	dir := t.TempDir()
	path, err := ResolvePath(dir)
	if err != nil || path != filepath.Join(dir, DatabaseName) {
		t.Fatalf("fresh install: %q %v", path, err)
	}

	// A pre-rename database keeps being used in place.
	touch(t, filepath.Join(dir, LegacyDatabaseName))
	path, err = ResolvePath(dir)
	if err != nil || path != filepath.Join(dir, LegacyDatabaseName) {
		t.Fatalf("legacy install: %q %v", path, err)
	}

	// Both files exist, so opening either one could silently pick wrong data.
	touch(t, filepath.Join(dir, DatabaseName))
	if _, err = ResolvePath(dir); err == nil {
		t.Fatal("ambiguous database files accepted")
	}
}

func TestResolvePathIgnoresDirectoryNamedLikeLegacyDatabase(t *testing.T) {
	dir := t.TempDir()
	if err := os.Mkdir(filepath.Join(dir, LegacyDatabaseName), 0700); err != nil {
		t.Fatal(err)
	}
	path, err := ResolvePath(dir)
	if err != nil || path != filepath.Join(dir, DatabaseName) {
		t.Fatalf("directory treated as a database: %q %v", path, err)
	}
}

func TestV1UpgradePreservesDataAndBacksUp(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, DatabaseName)
	db, err := sql.Open("sqlite", path)
	if err != nil {
		t.Fatal(err)
	}
	if _, err = db.Exec(schema); err != nil {
		t.Fatal(err)
	}
	if _, err = db.Exec(`PRAGMA user_version=1;INSERT INTO user(id,username)VALUES(1,'old');INSERT INTO wrong_question(id,user_id,subject,question_core,semantic_summary,mastery_status)VALUES(1,1,'math','cos x','','mastered');`); err != nil {
		t.Fatal(err)
	}
	db.Close()
	db, err = Open(dir)
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	var text, status string
	var due int64
	err = db.QueryRow(`SELECT q.search_text,q.mastery_status,p.due_at FROM wrong_question q JOIN review_plan p ON p.question_id=q.id WHERE q.id=1`).Scan(&text, &status, &due)
	if err != nil || text != "cosx" || status != "mastered" || due < time.Now().Add(6*24*time.Hour).Unix() {
		t.Fatal(text, status, due, err)
	}
	backups, _ := filepath.Glob(filepath.Join(dir, "before-upgrade-*.db"))
	if len(backups) != 1 {
		t.Fatal("backup missing")
	}
	if err = migrate(db, dir); err != nil {
		t.Fatal("migration not idempotent", err)
	}
}
