package oss

import (
	"context"
	"fmt"
	"io"
	"os"
	"path/filepath"
)

type LocalStore struct{ Root string }

func (s *LocalStore) EnsureReady(ctx context.Context) error { return os.MkdirAll(s.Root, 0700) }
func (s *LocalStore) Upload(ctx context.Context, key string, r io.Reader, size int64, contentType string) (string, error) {
	if !filepath.IsLocal(key) {
		return "", fmt.Errorf("invalid file path")
	}
	target := filepath.Join(s.Root, filepath.FromSlash(key))
	if err := os.MkdirAll(filepath.Dir(target), 0700); err != nil {
		return "", err
	}
	f, err := os.CreateTemp(filepath.Dir(target), ".upload-*")
	if err != nil {
		return "", err
	}
	defer os.Remove(f.Name())
	n, err := io.Copy(f, io.LimitReader(r, 20*1024*1024+1))
	if err == nil && n > 20*1024*1024 {
		err = fmt.Errorf("image exceeds 20 MB")
	}
	if err == nil {
		err = f.Sync()
	}
	closeErr := f.Close()
	if err != nil {
		return "", err
	}
	if closeErr != nil {
		return "", closeErr
	}
	if err = os.Rename(f.Name(), target); err != nil {
		return "", err
	}
	return "/api/v1/files/content/" + key, nil
}
