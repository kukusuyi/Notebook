package ai

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"path"
	"slices"
	"strings"
	"time"

	"mathnotebook/backend/internal/config"
)

const (
	ProviderTypeQwen             = "qwen"
	ProviderTypeDeepSeek         = "deepseek"
	ProviderTypeKimi             = "kimi"
	ProviderTypeOpenAICompatible = "openai_compatible"
)

type Message struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type CompletionRequest struct {
	Model    string
	Messages []Message
}

type CompletionResponse struct {
	Content string
}

type ProviderModel struct {
	ID string
}

type ProviderClient interface {
	ChatCompletion(ctx context.Context, req CompletionRequest) (CompletionResponse, error)
	ListModels(ctx context.Context) ([]ProviderModel, error)
	Config() config.AIModelConfig
}

type Registry struct {
	providers map[string]ProviderClient
}

func NewRegistry(cfgs []config.AIModelConfig) (*Registry, error) {
	providers := make(map[string]ProviderClient, len(cfgs))
	for _, cfg := range cfgs {
		name := strings.TrimSpace(cfg.Name)
		if name == "" {
			return nil, fmt.Errorf("model provider name is required")
		}
		if _, exists := providers[name]; exists {
			return nil, fmt.Errorf("duplicate model provider: %s", name)
		}

		client, err := newProviderClient(cfg)
		if err != nil {
			return nil, fmt.Errorf("build provider %s: %w", name, err)
		}
		providers[name] = client
	}

	return &Registry{providers: providers}, nil
}

func (r *Registry) Provider(name string) (ProviderClient, bool) {
	client, ok := r.providers[strings.TrimSpace(name)]
	return client, ok
}

func (r *Registry) Providers() []config.AIModelConfig {
	items := make([]config.AIModelConfig, 0, len(r.providers))
	for _, client := range r.providers {
		items = append(items, client.Config())
	}

	slices.SortFunc(items, func(a, b config.AIModelConfig) int {
		return strings.Compare(a.Name, b.Name)
	})

	return items
}

type openAICompatibleProvider struct {
	cfg        config.AIModelConfig
	httpClient *http.Client
}

func newProviderClient(cfg config.AIModelConfig) (ProviderClient, error) {
	normalized := normalizeProviderConfig(cfg)
	if normalized.BaseURL == "" {
		return nil, fmt.Errorf("base_url is required")
	}
	if normalized.APIKey == "" {
		return nil, fmt.Errorf("api_key is required")
	}

	switch normalized.ProviderType {
	case ProviderTypeQwen, ProviderTypeDeepSeek, ProviderTypeKimi, ProviderTypeOpenAICompatible:
		return &openAICompatibleProvider{
			cfg: normalized,
			httpClient: &http.Client{
				Timeout: 90 * time.Second,
			},
		}, nil
	default:
		return nil, fmt.Errorf("unsupported provider_type: %s", normalized.ProviderType)
	}
}

func normalizeProviderConfig(cfg config.AIModelConfig) config.AIModelConfig {
	cfg.Name = strings.TrimSpace(cfg.Name)
	cfg.ProviderType = strings.TrimSpace(cfg.ProviderType)
	cfg.BaseURL = strings.TrimRight(strings.TrimSpace(cfg.BaseURL), "/")
	cfg.Model = strings.TrimSpace(cfg.Model)
	cfg.APIKey = strings.TrimSpace(cfg.APIKey)
	if cfg.ProviderType == "" {
		switch strings.ToLower(cfg.Name) {
		case ProviderTypeQwen:
			cfg.ProviderType = ProviderTypeQwen
		case ProviderTypeDeepSeek:
			cfg.ProviderType = ProviderTypeDeepSeek
		case ProviderTypeKimi:
			cfg.ProviderType = ProviderTypeKimi
		default:
			cfg.ProviderType = ProviderTypeOpenAICompatible
		}
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

func (p *openAICompatibleProvider) Config() config.AIModelConfig {
	return p.cfg
}

func (p *openAICompatibleProvider) ListModels(ctx context.Context) ([]ProviderModel, error) {
	endpoint, err := appendBasePath(p.cfg.BaseURL, "models")
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return nil, fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+p.cfg.APIKey)

	resp, err := p.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("http call: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < http.StatusOK || resp.StatusCode >= http.StatusMultipleChoices {
		return nil, decodeProviderError(resp)
	}

	var body struct {
		Data []struct {
			ID string `json:"id"`
		} `json:"data"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		return nil, fmt.Errorf("decode response: %w", err)
	}

	models := make([]ProviderModel, 0, len(body.Data))
	for _, item := range body.Data {
		modelName := strings.TrimSpace(item.ID)
		if modelName == "" {
			continue
		}
		models = append(models, ProviderModel{ID: modelName})
	}

	slices.SortFunc(models, func(a, b ProviderModel) int {
		return strings.Compare(a.ID, b.ID)
	})

	return models, nil
}

func (p *openAICompatibleProvider) ChatCompletion(ctx context.Context, req CompletionRequest) (CompletionResponse, error) {
	endpoint, err := appendBasePath(p.cfg.BaseURL, "chat/completions")
	if err != nil {
		return CompletionResponse{}, err
	}

	payload := struct {
		Model       string    `json:"model"`
		Messages    []Message `json:"messages"`
		Temperature float64   `json:"temperature"`
	}{
		Model:       req.Model,
		Messages:    req.Messages,
		Temperature: 0.2,
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return CompletionResponse{}, fmt.Errorf("marshal request: %w", err)
	}

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(body))
	if err != nil {
		return CompletionResponse{}, fmt.Errorf("create request: %w", err)
	}
	httpReq.Header.Set("Authorization", "Bearer "+p.cfg.APIKey)
	httpReq.Header.Set("Content-Type", "application/json")

	resp, err := p.httpClient.Do(httpReq)
	if err != nil {
		return CompletionResponse{}, fmt.Errorf("http call: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < http.StatusOK || resp.StatusCode >= http.StatusMultipleChoices {
		return CompletionResponse{}, decodeProviderError(resp)
	}

	var chatResp struct {
		Choices []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		} `json:"choices"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&chatResp); err != nil {
		return CompletionResponse{}, fmt.Errorf("decode response: %w", err)
	}
	if len(chatResp.Choices) == 0 {
		return CompletionResponse{}, fmt.Errorf("no choices in response")
	}

	return CompletionResponse{
		Content: chatResp.Choices[0].Message.Content,
	}, nil
}

func decodeProviderError(resp *http.Response) error {
	var body struct {
		Error *struct {
			Message string `json:"message"`
			Type    string `json:"type"`
		} `json:"error"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&body); err == nil && body.Error != nil {
		return fmt.Errorf("provider error: %s (%s)", body.Error.Message, body.Error.Type)
	}
	return fmt.Errorf("provider returned status %d", resp.StatusCode)
}

func appendBasePath(baseURL string, suffix string) (string, error) {
	parsed, err := url.Parse(baseURL)
	if err != nil {
		return "", fmt.Errorf("invalid base_url: %w", err)
	}
	parsed.Path = path.Join(parsed.Path, suffix)
	return parsed.String(), nil
}
