package sqlite

import (
	"net/url"
	"os"
	"path/filepath"
	"testing"
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
