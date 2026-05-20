package ai

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"mathnotebook/backend/internal/config"
)

type EmbeddingClient interface {
	Embed(ctx context.Context, input string) ([]float64, error)
	ModelName() string
}

type openAICompatibleEmbeddingClient struct {
	cfg        config.EmbeddingModelConfig
	httpClient *http.Client
}

func NewEmbeddingClient(cfg config.EmbeddingModelConfig) (EmbeddingClient, error) {
	normalized := normalizeEmbeddingConfig(cfg)
	if normalized.BaseURL == "" {
		return nil, fmt.Errorf("embedding base_url is required")
	}
	if normalized.Model == "" {
		return nil, fmt.Errorf("embedding model is required")
	}
	if normalized.APIKey == "" {
		return nil, fmt.Errorf("embedding api_key is required")
	}

	switch normalized.ProviderType {
	case ProviderTypeQwen, ProviderTypeDeepSeek, ProviderTypeKimi, ProviderTypeOpenAICompatible:
		return &openAICompatibleEmbeddingClient{
			cfg: normalized,
			httpClient: &http.Client{
				Timeout: 90 * time.Second,
			},
		}, nil
	default:
		return nil, fmt.Errorf("unsupported embedding provider_type: %s", normalized.ProviderType)
	}
}

func normalizeEmbeddingConfig(cfg config.EmbeddingModelConfig) config.EmbeddingModelConfig {
	cfg.ProviderType = strings.TrimSpace(cfg.ProviderType)
	cfg.BaseURL = strings.TrimRight(strings.TrimSpace(cfg.BaseURL), "/")
	cfg.Model = strings.TrimSpace(cfg.Model)
	cfg.APIKey = strings.TrimSpace(cfg.APIKey)
	if cfg.ProviderType == "" {
		cfg.ProviderType = ProviderTypeOpenAICompatible
	}
	if cfg.BaseURL == "" {
		switch cfg.ProviderType {
		case ProviderTypeQwen:
			cfg.BaseURL = "https://dashscope.aliyuncs.com/compatible-mode/v1"
		case ProviderTypeDeepSeek:
			cfg.BaseURL = "https://api.deepseek.com"
		case ProviderTypeKimi:
			cfg.BaseURL = "https://api.moonshot.cn/v1"
		}
	}
	return cfg
}

func (c *openAICompatibleEmbeddingClient) ModelName() string {
	return c.cfg.Model
}

func (c *openAICompatibleEmbeddingClient) Embed(ctx context.Context, input string) ([]float64, error) {
	endpoint, err := appendBasePath(c.cfg.BaseURL, "embeddings")
	if err != nil {
		return nil, err
	}

	payload := struct {
		Model string `json:"model"`
		Input string `json:"input"`
	}{
		Model: c.cfg.Model,
		Input: strings.TrimSpace(input),
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return nil, fmt.Errorf("marshal embedding request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("create embedding request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+c.cfg.APIKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("embedding http call: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < http.StatusOK || resp.StatusCode >= http.StatusMultipleChoices {
		return nil, decodeProviderError(resp)
	}

	var response struct {
		Data []struct {
			Embedding []float64 `json:"embedding"`
		} `json:"data"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&response); err != nil {
		return nil, fmt.Errorf("decode embedding response: %w", err)
	}
	if len(response.Data) == 0 || len(response.Data[0].Embedding) == 0 {
		return nil, fmt.Errorf("embedding response is empty")
	}

	return response.Data[0].Embedding, nil
}
