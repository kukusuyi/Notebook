package oss

import (
	"context"
	"fmt"
	"io"

	"github.com/kukusuyi/Questrace/backend/internal/config"
)

type ObjectStore interface {
	EnsureReady(ctx context.Context) error
	Upload(ctx context.Context, objectKey string, reader io.Reader, size int64, contentType string) (string, error)
}

func NewClient(cfg config.FileConfig) (ObjectStore, error) {
	switch cfg.StorageProvider {
	case "local":
		return &LocalStore{Root: cfg.Root}, nil
	default:
		return nil, fmt.Errorf("unsupported file provider: %s", cfg.StorageProvider)
	}
}
