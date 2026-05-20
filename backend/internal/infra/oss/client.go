package oss

import (
	"context"
	"fmt"
	"io"

	"mathnotebook/backend/internal/config"
)

type ObjectStore interface {
	EnsureReady(ctx context.Context) error
	Upload(ctx context.Context, objectKey string, reader io.Reader, size int64, contentType string) (string, error)
}

func NewClient(cfg config.FileConfig) (ObjectStore, error) {
	switch config.NormalizeStorageProvider(cfg.StorageProvider) {
	case "oss", "minio", "":
		return newMinIOClient(cfg)
	case "lightcos":
		return newLightCOSClient(cfg)
	default:
		return nil, fmt.Errorf("unsupported file provider: %s", cfg.StorageProvider)
	}
}
