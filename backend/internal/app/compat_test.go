package app

import (
	"archive/zip"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	"github.com/kukusuyi/Questrace/backend/internal/config"
	"github.com/kukusuyi/Questrace/backend/internal/infra/sqlite"
	"github.com/kukusuyi/Questrace/backend/internal/pkg/session"
)

// archivePreRenameBackup writes a backup archive as 2.0 produced it: the database
// keeps its old file name inside the zip.
func archivePreRenameBackup(t *testing.T, dir, target string) {
	t.Helper()
	f, err := os.Create(target)
	if err != nil {
		t.Fatal(err)
	}
	zw := zip.NewWriter(f)
	add := func(name, source string) {
		info, err := os.Stat(source)
		if err != nil {
			t.Fatal(err)
		}
		h, err := zip.FileInfoHeader(info)
		if err != nil {
			t.Fatal(err)
		}
		h.Name = name
		h.Method = zip.Deflate
		w, err := zw.CreateHeader(h)
		if err != nil {
			t.Fatal(err)
		}
		in, err := os.Open(source)
		if err != nil {
			t.Fatal(err)
		}
		defer in.Close()
		if _, err = io.Copy(w, in); err != nil {
			t.Fatal(err)
		}
	}
	add(sqlite.LegacyDatabaseName, filepath.Join(dir, sqlite.DatabaseName))
	add("settings.json", filepath.Join(dir, "settings.json"))
	if err = zw.Close(); err != nil {
		t.Fatal(err)
	}
	if err = f.Close(); err != nil {
		t.Fatal(err)
	}
}

func TestRestorePreRenameBackupNormalisesDatabaseName(t *testing.T) {
	rt := newTestRuntime(t)
	setupAndLogin(t, rt)
	source := rt.Config().DataDir
	rt.DB.Close()
	archive := filepath.Join(t.TempDir(), "legacy-backup.zip")
	archivePreRenameBackup(t, source, archive)

	target := t.TempDir()
	if err := Restore(target, archive); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(target, sqlite.DatabaseName)); err != nil {
		t.Fatalf("restored database missing: %v", err)
	}
	if _, err := os.Stat(filepath.Join(target, sqlite.LegacyDatabaseName)); !os.IsNotExist(err) {
		t.Fatal("pre-rename database name survived restore")
	}
	cfg, err := config.LoadLocal(target)
	if err != nil {
		t.Fatal(err)
	}
	restored, err := NewLocal(cfg, slog.New(slog.NewTextHandler(io.Discard, nil)))
	if err != nil {
		t.Fatal(err)
	}
	defer restored.DB.Close()
	if restored.NeedsSetup() {
		t.Fatal("restored account lost")
	}
}

func TestBackupOfPreRenameDatabaseUsesCurrentName(t *testing.T) {
	rt := newTestRuntime(t)
	setupAndLogin(t, rt)
	dir := rt.Config().DataDir
	rt.DB.Close()
	// An upgraded installation keeps its database file in place.
	if err := os.Rename(filepath.Join(dir, sqlite.DatabaseName), filepath.Join(dir, sqlite.LegacyDatabaseName)); err != nil {
		t.Fatal(err)
	}
	archive := filepath.Join(t.TempDir(), "backup.zip")
	if err := Backup(dir, archive); err != nil {
		t.Fatal(err)
	}
	reader, err := zip.OpenReader(archive)
	if err != nil {
		t.Fatal(err)
	}
	defer reader.Close()
	names := map[string]bool{}
	for _, entry := range reader.File {
		names[entry.Name] = true
	}
	if !names[sqlite.DatabaseName] {
		t.Fatalf("backup does not carry %s: %v", sqlite.DatabaseName, names)
	}
	if names[sqlite.LegacyDatabaseName] {
		t.Fatalf("backup kept the pre-rename database name: %v", names)
	}
}

func TestSessionCookieRename(t *testing.T) {
	rt := newTestRuntime(t)
	token := setupAndLogin(t, rt)

	// Login writes the current cookie name.
	w := httptest.NewRecorder()
	r := httptest.NewRequest("POST", "/api/v1/auth/login", strings.NewReader(`{"username":"owner","password":"password123"}`))
	r.Header.Set("Content-Type", "application/json")
	rt.ServeHTTP(w, r)
	if w.Code != 200 {
		t.Fatalf("login: %d", w.Code)
	}
	var issued []string
	for _, c := range w.Result().Cookies() {
		issued = append(issued, c.Name)
	}
	if !slices.Contains(issued, session.CookieName) {
		t.Fatalf("login did not set %s: %v", session.CookieName, issued)
	}

	// A browser that still holds the pre-rename cookie stays signed in.
	w = httptest.NewRecorder()
	r = httptest.NewRequest("GET", "/api/v1/vector-jobs", nil)
	r.AddCookie(&http.Cookie{Name: session.LegacyCookieName, Value: token})
	rt.ServeHTTP(w, r)
	if w.Code != 200 {
		t.Fatalf("pre-rename cookie rejected: %d", w.Code)
	}

	// Logout clears both names.
	w = httptest.NewRecorder()
	rt.ServeHTTP(w, httptest.NewRequest("POST", "/api/v1/auth/logout", nil))
	cleared := map[string]bool{}
	for _, c := range w.Result().Cookies() {
		if c.Value == "" {
			cleared[c.Name] = true
		}
	}
	for _, name := range []string{session.CookieName, session.LegacyCookieName} {
		if !cleared[name] {
			t.Fatalf("logout did not clear %s: %v", name, cleared)
		}
	}
}
