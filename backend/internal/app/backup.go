package app

import (
	"archive/zip"
	"encoding/json"
	"fmt"
	"io"
	"mathnotebook/backend/internal/config"
	"os"
	"path/filepath"
	"strings"
	"time"

	"mathnotebook/backend/internal/infra/sqlite"
)

// Backup and Restore require the CLI's exclusive data-directory lock.
func Backup(dir, target string) error {
	target, err := filepath.Abs(target)
	if err != nil {
		return err
	}
	if rel, e := filepath.Rel(dir, target); e == nil && filepath.IsLocal(rel) {
		return fmt.Errorf("备份文件必须位于数据目录之外")
	}
	db, err := sqlite.Open(dir)
	if err != nil {
		return err
	}
	if _, err = db.Exec("PRAGMA wal_checkpoint(TRUNCATE)"); err != nil {
		db.Close()
		return err
	}
	if err = db.Close(); err != nil {
		return err
	}
	f, err := os.CreateTemp(filepath.Dir(target), ".notebook-backup-*")
	if err != nil {
		return err
	}
	defer os.Remove(f.Name())
	zw := zip.NewWriter(f)
	err = filepath.WalkDir(dir, func(path string, d os.DirEntry, e error) error {
		if e != nil {
			return e
		}
		if d.IsDir() {
			return nil
		}
		rel, e := filepath.Rel(dir, path)
		if e != nil {
			return e
		}
		if rel != "notebook.db" && rel != "settings.json" && !strings.HasPrefix(filepath.ToSlash(rel), "files/") {
			return nil
		}
		info, e := d.Info()
		if e != nil {
			return e
		}
		if !info.Mode().IsRegular() {
			return fmt.Errorf("unsupported backup entry")
		}
		h, e := zip.FileInfoHeader(info)
		if e != nil {
			return e
		}
		h.Name = filepath.ToSlash(rel)
		h.Method = zip.Deflate
		w, e := zw.CreateHeader(h)
		if e != nil {
			return e
		}
		in, e := os.Open(path)
		if e != nil {
			return e
		}
		defer in.Close()
		_, e = io.Copy(w, in)
		return e
	})
	ze := zw.Close()
	fe := f.Close()
	if err != nil {
		return err
	}
	if ze != nil {
		return ze
	}
	if fe != nil {
		return fe
	}
	return os.Rename(f.Name(), target)
}
func Restore(dir, source string) error {
	reader, err := zip.OpenReader(source)
	if err != nil {
		return err
	}
	defer reader.Close()
	stage, err := os.MkdirTemp(filepath.Dir(dir), ".notebook-restore-*")
	if err != nil {
		return err
	}
	defer os.RemoveAll(stage)
	var total uint64
	seen := map[string]bool{}
	for _, entry := range reader.File {
		name := entry.Name
		if !filepath.IsLocal(name) || strings.Contains(name, "\\") || entry.Mode()&os.ModeSymlink != 0 {
			return fmt.Errorf("invalid backup path")
		}
		if name != "notebook.db" && name != "settings.json" && !strings.HasPrefix(name, "files/") {
			return fmt.Errorf("unexpected backup entry %s", name)
		}
		if seen[name] {
			return fmt.Errorf("duplicate backup entry")
		}
		seen[name] = true
		total += entry.UncompressedSize64
		if total > 20*1024*1024*1024 {
			return fmt.Errorf("backup exceeds 20 GB")
		}
		path := filepath.Join(stage, filepath.FromSlash(name))
		if entry.FileInfo().IsDir() {
			continue
		}
		if err = os.MkdirAll(filepath.Dir(path), 0700); err != nil {
			return err
		}
		in, e := entry.Open()
		if e != nil {
			return e
		}
		out, e := os.OpenFile(path, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
		if e != nil {
			in.Close()
			return e
		}
		_, e = io.Copy(out, io.LimitReader(in, int64(entry.UncompressedSize64)+1))
		ce := out.Close()
		in.Close()
		if e != nil {
			return e
		}
		if ce != nil {
			return ce
		}
	}
	if !seen["notebook.db"] || !seen["settings.json"] {
		return fmt.Errorf("incomplete backup")
	}
	data, err := os.ReadFile(filepath.Join(stage, "settings.json"))
	if err != nil {
		return err
	}
	var cfg config.Config
	if err = json.Unmarshal(data, &cfg); err != nil {
		return fmt.Errorf("invalid backup settings: %w", err)
	}
	if cfg.JWT.Secret == "" {
		return fmt.Errorf("backup missing authentication configuration")
	}
	db, err := sqlite.Open(stage)
	if err != nil {
		return err
	}
	var check string
	err = db.QueryRow("PRAGMA integrity_check").Scan(&check)
	db.Close()
	if err != nil {
		return err
	}
	if check != "ok" {
		return fmt.Errorf("database integrity check: %s", check)
	}
	old := dir + fmt.Sprintf(".before-restore-%d", time.Now().UnixNano())
	if err = os.Rename(dir, old); err != nil {
		return err
	}
	if err = os.Rename(stage, dir); err != nil {
		_ = os.Rename(old, dir)
		return err
	}
	return nil
}
