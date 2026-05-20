package oss

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"

	cos "github.com/tencentyun/cos-go-sdk-v5"

	"mathnotebook/backend/internal/config"
)

type lightCOSClient struct {
	client        *cos.Client
	publicBaseURL string
}

func newLightCOSClient(cfg config.FileConfig) (ObjectStore, error) {
	if strings.TrimSpace(cfg.DefaultBucket) == "" {
		return nil, fmt.Errorf("file bucket is required")
	}
	if strings.TrimSpace(cfg.LightCOS.BucketURL) == "" {
		return nil, fmt.Errorf("file.lightcos.bucket_url is required")
	}
	if strings.TrimSpace(cfg.LightCOS.SecretID) == "" || strings.TrimSpace(cfg.LightCOS.SecretKey) == "" {
		return nil, fmt.Errorf("file.lightcos secret_id and secret_key are required")
	}

	bucketURL, err := url.Parse(strings.TrimSpace(cfg.LightCOS.BucketURL))
	if err != nil {
		return nil, fmt.Errorf("parse lightcos bucket_url: %w", err)
	}

	client := cos.NewClient(&cos.BaseURL{BucketURL: bucketURL}, &http.Client{
		Transport: &cos.AuthorizationTransport{
			SecretID:  cfg.LightCOS.SecretID,
			SecretKey: cfg.LightCOS.SecretKey,
		},
	})

	publicBaseURL := strings.TrimSpace(cfg.PublicBaseURL())
	if publicBaseURL == "" {
		publicBaseURL = strings.TrimRight(strings.TrimSpace(cfg.LightCOS.BucketURL), "/")
	}

	return &lightCOSClient{
		client:        client,
		publicBaseURL: strings.TrimRight(publicBaseURL, "/"),
	}, nil
}

func (c *lightCOSClient) EnsureReady(context.Context) error {
	return nil
}

func (c *lightCOSClient) Upload(ctx context.Context, objectKey string, reader io.Reader, size int64, contentType string) (string, error) {
	opt := &cos.ObjectPutOptions{
		ObjectPutHeaderOptions: &cos.ObjectPutHeaderOptions{
			ContentType:   contentType,
			ContentLength: size,
		},
	}

	_, err := c.client.Object.Put(ctx, normalizeObjectKey(objectKey), reader, opt)
	if err != nil {
		return "", fmt.Errorf("put object %s: %w", objectKey, err)
	}

	return fmt.Sprintf("%s/%s", c.publicBaseURL, normalizeObjectKey(objectKey)), nil
}
