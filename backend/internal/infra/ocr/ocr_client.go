package ocr

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"mime"
	"net"
	"net/http"
	"net/url"
	"path/filepath"
	"strings"
	"time"
)

const (
	DashScopeBaseURL = "https://dashscope.aliyuncs.com/compatible-mode/v1"
)

type OCRClient interface {
	Recognize(ctx context.Context, imageURL string, prompt string) (string, error)
}

type QwenOCRClient struct {
	apiKey         string
	model          string
	httpClient     *http.Client // 调用百炼 API（长超时）
	downloadClient *http.Client // 下载本地图片（短超时）
	logger         *slog.Logger
}

func NewQwenOCRClient(apiKey string, model string) *QwenOCRClient {
	return NewQwenOCRClientWithLogger(apiKey, model, nil)
}

func NewQwenOCRClientWithLogger(apiKey string, model string, logger *slog.Logger) *QwenOCRClient {
	if model == "" {
		model = "qwen3.6-plus"
	}
	if logger == nil {
		logger = slog.Default()
	}
	return &QwenOCRClient{
		apiKey: apiKey,
		model:  model,
		httpClient: &http.Client{
			Timeout: 300 * time.Second,
		},
		downloadClient: &http.Client{
			Timeout: 30 * time.Second, // 本地下载应该很快
		},
		logger: logger,
	}
}

type chatRequest struct {
	Model          string    `json:"model"`
	Messages       []message `json:"messages"`
	EnableThinking *bool     `json:"enable_thinking,omitempty"`
}

type message struct {
	Role    string    `json:"role"`
	Content []content `json:"content"`
}

type content struct {
	Type     string           `json:"type"`
	Text     string           `json:"text,omitempty"`
	ImageURL *imageURLPayload `json:"image_url,omitempty"`
}

type imageURLPayload struct {
	URL string `json:"url"`
}

type chatResponse struct {
	Choices []struct {
		Message struct {
			Content string `json:"content"`
		} `json:"message"`
	} `json:"choices"`
	Error *struct {
		Message string `json:"message"`
		Type    string `json:"type"`
	} `json:"error,omitempty"`
}

func (c *QwenOCRClient) Recognize(ctx context.Context, imageURL string, prompt string) (string, error) {
	c.logger.Info(
		"sending OCR prompt to provider",
		"model", c.model,
		"image_url", imageURL,
		"prompt", prompt,
	)

	imageContent, err := c.buildImageContent(ctx, imageURL)
	if err != nil {
		return "", err
	}

	noThinking := false
	reqBody := chatRequest{
		Model:          c.model,
		EnableThinking: &noThinking,
		Messages: []message{
			{
				Role: "system",
				Content: []content{
					{
						Type: "text",
						Text: prompt,
					},
				},
			},
			{
				Role: "user",
				Content: []content{
					imageContent,
					{
						Type: "text",
						Text: "请严格按照系统规则抽取图片内容，只输出 JSON，不要解释。",
					},
				},
			},
		},
	}

	body, err := json.Marshal(reqBody)
	if err != nil {
		return "", fmt.Errorf("marshal request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, DashScopeBaseURL+"/chat/completions", bytes.NewReader(body))
	if err != nil {
		return "", fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+c.apiKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("http call: %w", err)
	}
	defer resp.Body.Close()

	var chatResp chatResponse
	if err := json.NewDecoder(resp.Body).Decode(&chatResp); err != nil {
		return "", fmt.Errorf("decode response: %w", err)
	}

	if chatResp.Error != nil {
		return "", fmt.Errorf("api error: %s (%s)", chatResp.Error.Message, chatResp.Error.Type)
	}

	if len(chatResp.Choices) == 0 {
		return "", fmt.Errorf("no choices in response")
	}

	return chatResp.Choices[0].Message.Content, nil
}

func (c *QwenOCRClient) buildImageContent(ctx context.Context, imageURL string) (content, error) {
	resolvedURL := imageURL
	if shouldInlineImageURL(imageURL) {
		dataURL, err := c.downloadAsDataURL(ctx, imageURL)
		if err != nil {
			return content{}, fmt.Errorf("prepare image payload: %w", err)
		}
		resolvedURL = dataURL
		c.logger.Debug("inlined local OCR image as data URL", "source", imageURL)
	}

	return content{
		Type:     "image_url",
		ImageURL: &imageURLPayload{URL: resolvedURL},
	}, nil
}

func shouldInlineImageURL(rawURL string) bool {
	parsed, err := url.Parse(rawURL)
	if err != nil {
		return false
	}
	if strings.EqualFold(parsed.Scheme, "data") {
		return false
	}

	host := parsed.Hostname()
	if host == "" {
		return false
	}
	if strings.EqualFold(host, "localhost") {
		return true
	}

	ip := net.ParseIP(host)
	if ip == nil {
		return false
	}

	return ip.IsLoopback() || ip.IsPrivate() || ip.IsLinkLocalMulticast() || ip.IsLinkLocalUnicast() || ip.IsUnspecified()
}

func (c *QwenOCRClient) downloadAsDataURL(ctx context.Context, imageURL string) (string, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, imageURL, nil)
	if err != nil {
		return "", fmt.Errorf("create download request: %w", err)
	}

	resp, err := c.downloadClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("download image: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < http.StatusOK || resp.StatusCode >= http.StatusMultipleChoices {
		return "", fmt.Errorf("download image: unexpected status %d", resp.StatusCode)
	}

	imageBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("read image: %w", err)
	}
	if len(imageBytes) == 0 {
		return "", fmt.Errorf("read image: empty body")
	}

	contentType := detectImageContentType(resp, imageURL, imageBytes)
	if !strings.HasPrefix(contentType, "image/") {
		return "", fmt.Errorf("download image: unexpected content type %q", contentType)
	}

	return "data:" + contentType + ";base64," + base64.StdEncoding.EncodeToString(imageBytes), nil
}

func detectImageContentType(resp *http.Response, imageURL string, imageBytes []byte) string {
	contentType := strings.TrimSpace(resp.Header.Get("Content-Type"))
	if contentType != "" {
		if mediaType, _, err := mime.ParseMediaType(contentType); err == nil && mediaType != "" {
			if !isGenericBinaryContentType(mediaType) {
				return mediaType
			}
		} else if !isGenericBinaryContentType(contentType) {
			return contentType
		}
	}

	if extType := mime.TypeByExtension(filepath.Ext(imageURL)); extType != "" {
		if mediaType, _, err := mime.ParseMediaType(extType); err == nil && mediaType != "" {
			return mediaType
		}
		return extType
	}

	return http.DetectContentType(imageBytes)
}

func isGenericBinaryContentType(contentType string) bool {
	normalized := strings.ToLower(strings.TrimSpace(contentType))
	return normalized == "application/octet-stream" || normalized == "binary/octet-stream"
}
