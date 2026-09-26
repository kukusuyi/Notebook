package config

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
)

const (
	// AppName names the data directory of a fresh installation.
	AppName = "Questrace"
	// LegacyAppName is the pre-rename product name. An existing data directory
	// keeps being used in place so upgrades never move user data.
	LegacyAppName = "Notebook"

	// EnvDataDir overrides the data directory without a command-line flag.
	EnvDataDir = "QUESTRACE_DATA_DIR"
	// EnvLegacyDataDir is the pre-rename alias, honoured at lower priority.
	EnvLegacyDataDir = "NOTEBOOK_DATA_DIR"
)

// dataRoot is the platform directory that holds per-application data.
func dataRoot() (string, error) {
	if runtime.GOOS == "linux" {
		base := os.Getenv("XDG_DATA_HOME")
		if base == "" {
			home, err := os.UserHomeDir()
			if err != nil {
				return "", err
			}
			base = filepath.Join(home, ".local", "share")
		}
		return base, nil
	}
	return os.UserConfigDir()
}

// DefaultDataDir is the directory a fresh installation uses.
func DefaultDataDir() (string, error) {
	base, err := dataRoot()
	if err != nil {
		return "", err
	}
	return filepath.Join(base, AppName), nil
}

// ResolveDataDir picks the data directory when neither a flag nor an environment
// variable selects one. A lone legacy directory is reused in place; when both the
// new and the legacy directory exist the choice is ambiguous, so startup stops
// instead of silently opening the wrong data.
func ResolveDataDir() (string, error) {
	base, err := dataRoot()
	if err != nil {
		return "", err
	}
	current := filepath.Join(base, AppName)
	legacy := filepath.Join(base, LegacyAppName)
	hasCurrent := isDirectory(current)
	hasLegacy := isDirectory(legacy)
	if hasCurrent && hasLegacy {
		return "", fmt.Errorf("同时存在数据目录 %s 与 %s，请保留其中一个，或用 --data-dir / %s 指定要使用的目录", current, legacy, EnvDataDir)
	}
	if hasLegacy {
		return legacy, nil
	}
	return current, nil
}

// DataDirFromEnv reads the data directory from the environment, preferring the
// current variable and falling back to the legacy alias.
func DataDirFromEnv() string {
	if dir := os.Getenv(EnvDataDir); dir != "" {
		return dir
	}
	return os.Getenv(EnvLegacyDataDir)
}

// SelectDataDir returns the data directory to use. An explicit command-line value
// always wins, then the environment, and only then the platform default.
func SelectDataDir(explicit string) (string, error) {
	if explicit != "" {
		return explicit, nil
	}
	if dir := DataDirFromEnv(); dir != "" {
		return dir, nil
	}
	return ResolveDataDir()
}

func isDirectory(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.IsDir()
}

func RandomSecret() string {
	var b [32]byte
	if _, err := rand.Read(b[:]); err != nil {
		panic(err)
	}
	return hex.EncodeToString(b[:])
}
func LoadLocal(dir string) (Config, error) {
	cfg := defaults()
	cfg.DataDir = dir
	cfg.Auth.EnableRegistration = false
	cfg.File.StorageProvider = "local"
	cfg.File.Root = filepath.Join(dir, "files")
	cfg.MobileVersion.Version = "2.0.0"
	if err := os.MkdirAll(cfg.File.Root, 0700); err != nil {
		return cfg, fmt.Errorf("data directory is not writable: %w", err)
	}
	data, err := os.ReadFile(filepath.Join(dir, "settings.json"))
	if err == nil {
		if err = json.Unmarshal(data, &cfg); err != nil {
			return cfg, fmt.Errorf("invalid settings: %w", err)
		}
	} else if !os.IsNotExist(err) {
		return cfg, err
	}
	cfg.DataDir = dir
	cfg.File.Root = filepath.Join(dir, "files")
	cfg.File.StorageProvider = "local"
	if (runtime.GOOS == "darwin" || runtime.GOOS == "windows") && cfg.DeviceID == "" {
		cfg.DeviceID = RandomSecret()[:12]
	}
	if cfg.JWT.Secret == "" {
		cfg.JWT.Secret = RandomSecret()
	}
	if cfg.SetupToken == "" {
		cfg.SetupToken = RandomSecret()
	}
	return cfg, SaveLocal(cfg)
}
func SaveLocal(cfg Config) error {
	data, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		return err
	}
	f, err := os.CreateTemp(cfg.DataDir, ".settings-*")
	if err != nil {
		return err
	}
	name := f.Name()
	defer os.Remove(name)
	if _, err = f.Write(data); err != nil {
		f.Close()
		return err
	}
	if err = f.Sync(); err != nil {
		f.Close()
		return err
	}
	if err = f.Close(); err != nil {
		return err
	}
	return os.Rename(name, filepath.Join(cfg.DataDir, "settings.json"))
}
