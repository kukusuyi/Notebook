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

func DefaultDataDir() (string, error) {
	if runtime.GOOS == "linux" {
		base := os.Getenv("XDG_DATA_HOME")
		if base == "" {
			home, err := os.UserHomeDir()
			if err != nil {
				return "", err
			}
			base = filepath.Join(home, ".local", "share")
		}
		return filepath.Join(base, "Notebook"), nil
	}
	base, err := os.UserConfigDir()
	return filepath.Join(base, "Notebook"), err
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
