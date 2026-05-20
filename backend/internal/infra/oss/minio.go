package oss

import (
	"context"
	"fmt"
	"io"
	"strings"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"

	"mathnotebook/backend/internal/config"
)

type minIOClient struct {
	client        *minio.Client
	bucket        string
	publicBaseURL string
	autoCreate    bool
	publicRead    bool
	region        string
}

func newMinIOClient(cfg config.FileConfig) (ObjectStore, error) {
	if strings.TrimSpace(cfg.DefaultBucket) == "" {
		return nil, fmt.Errorf("file bucket is required")
	}
	if strings.TrimSpace(cfg.MinIO.Endpoint) == "" {
		return nil, fmt.Errorf("file.minio.endpoint is required")
	}
	if strings.TrimSpace(cfg.MinIO.AccessKey) == "" || strings.TrimSpace(cfg.MinIO.SecretKey) == "" {
		return nil, fmt.Errorf("file.minio access_key and secret_key are required")
	}

	client, err := minio.New(cfg.MinIO.Endpoint, &minio.Options{
		Creds:        credentials.NewStaticV4(cfg.MinIO.AccessKey, cfg.MinIO.SecretKey, ""),
		Secure:       cfg.MinIO.UseSSL,
		Region:       cfg.MinIO.Region,
		BucketLookup: minio.BucketLookupPath,
	})
	if err != nil {
		return nil, fmt.Errorf("create minio client: %w", err)
	}

	publicBaseURL := strings.TrimSpace(cfg.PublicBaseURL())
	if publicBaseURL == "" {
		scheme := "http"
		if cfg.MinIO.UseSSL {
			scheme = "https"
		}
		publicBaseURL = scheme + "://" + cfg.MinIO.Endpoint
	}

	return &minIOClient{
		client:        client,
		bucket:        cfg.DefaultBucket,
		publicBaseURL: strings.TrimRight(publicBaseURL, "/"),
		autoCreate:    cfg.MinIO.AutoCreateBucket,
		publicRead:    cfg.MinIO.PublicRead,
		region:        cfg.MinIO.Region,
	}, nil
}

func (c *minIOClient) EnsureReady(ctx context.Context) error {
	exists, err := c.client.BucketExists(ctx, c.bucket)
	if err != nil {
		return fmt.Errorf("check bucket %s: %w", c.bucket, err)
	}

	if !exists {
		if !c.autoCreate {
			return fmt.Errorf("bucket %s does not exist", c.bucket)
		}
		if err := c.client.MakeBucket(ctx, c.bucket, minio.MakeBucketOptions{Region: c.region}); err != nil {
			existsAfterCreate, existsErr := c.client.BucketExists(ctx, c.bucket)
			if existsErr != nil || !existsAfterCreate {
				return fmt.Errorf("create bucket %s: %w", c.bucket, err)
			}
		}
	}

	if c.publicRead {
		if err := c.client.SetBucketPolicy(ctx, c.bucket, publicReadPolicy(c.bucket)); err != nil {
			return fmt.Errorf("set bucket policy %s: %w", c.bucket, err)
		}
	}

	return nil
}

func (c *minIOClient) Upload(ctx context.Context, objectKey string, reader io.Reader, size int64, contentType string) (string, error) {
	if _, err := c.client.PutObject(ctx, c.bucket, normalizeObjectKey(objectKey), reader, size, minio.PutObjectOptions{
		ContentType: contentType,
	}); err != nil {
		return "", fmt.Errorf("put object %s: %w", objectKey, err)
	}

	return fmt.Sprintf("%s/%s/%s", c.publicBaseURL, c.bucket, normalizeObjectKey(objectKey)), nil
}

func publicReadPolicy(bucket string) string {
	return fmt.Sprintf(`{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"AWS":["*"]},"Action":["s3:GetObject"],"Resource":["arn:aws:s3:::%s/*"]}]}`, bucket)
}

func normalizeObjectKey(objectKey string) string {
	return strings.TrimLeft(strings.ReplaceAll(objectKey, "\\", "/"), "/")
}
