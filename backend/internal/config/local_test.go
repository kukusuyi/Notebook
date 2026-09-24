package config

import (
	"os"
	"path/filepath"
	"testing"
)

func TestResolveDataDir(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_DATA_HOME", filepath.Join(home, "xdg-data"))
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, "xdg-config"))

	current, err := DefaultDataDir()
	if err != nil {
		t.Fatal(err)
	}
	legacy := filepath.Join(filepath.Dir(current), LegacyAppName)
	if current == legacy {
		t.Fatal("current and legacy data directories must differ")
	}

	// A fresh installation uses the new directory, even before it exists.
	got, err := ResolveDataDir()
	if err != nil || got != current {
		t.Fatalf("fresh install: %q %v", got, err)
	}

	// Only a pre-rename directory exists: it keeps being used in place.
	if err = os.MkdirAll(legacy, 0700); err != nil {
		t.Fatal(err)
	}
	if got, err = ResolveDataDir(); err != nil || got != legacy {
		t.Fatalf("legacy install: %q %v", got, err)
	}
	if _, err = os.Stat(legacy); err != nil {
		t.Fatalf("legacy directory was moved: %v", err)
	}

	// Both directories exist, so the choice would be arbitrary.
	if err = os.MkdirAll(current, 0700); err != nil {
		t.Fatal(err)
	}
	if _, err = ResolveDataDir(); err == nil {
		t.Fatal("ambiguous data directories accepted")
	}
}

func TestDataDirFromEnvPrefersCurrentName(t *testing.T) {
	t.Setenv(EnvDataDir, "current-dir")
	t.Setenv(EnvLegacyDataDir, "legacy-dir")
	if got := DataDirFromEnv(); got != "current-dir" {
		t.Fatalf("current variable ignored: %q", got)
	}

	t.Setenv(EnvDataDir, "")
	if got := DataDirFromEnv(); got != "legacy-dir" {
		t.Fatalf("legacy alias ignored: %q", got)
	}

	t.Setenv(EnvLegacyDataDir, "")
	if got := DataDirFromEnv(); got != "" {
		t.Fatalf("unset environment returned %q", got)
	}
}

func TestSelectDataDir(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_DATA_HOME", filepath.Join(home, "xdg-data"))
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, "xdg-config"))
	t.Setenv(EnvDataDir, "from-environment")

	// An explicit value always wins, even when the environment is set.
	got, err := SelectDataDir("/explicit")
	if err != nil || got != "/explicit" {
		t.Fatalf("explicit directory ignored: %q %v", got, err)
	}

	// Without an explicit value the environment is used.
	if got, err = SelectDataDir(""); err != nil || got != "from-environment" {
		t.Fatalf("environment ignored: %q %v", got, err)
	}

	// With neither, the platform directory is resolved; an ambiguous pair is
	// reported instead of guessed.
	current, err := DefaultDataDir()
	if err != nil {
		t.Fatal(err)
	}
	for _, dir := range []string{current, filepath.Join(filepath.Dir(current), LegacyAppName)} {
		if err = os.MkdirAll(dir, 0700); err != nil {
			t.Fatal(err)
		}
	}
	t.Setenv(EnvDataDir, "")
	if _, err = SelectDataDir(""); err == nil {
		t.Fatal("ambiguous data directories accepted")
	}
}
