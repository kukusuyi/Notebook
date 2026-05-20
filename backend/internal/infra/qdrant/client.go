package qdrant

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	"mathnotebook/backend/internal/config"
)

type Client struct {
	baseURL        string
	apiKey         string
	collectionName string
	distance       string
	httpClient     *http.Client
	mu             sync.Mutex
	ensuredSize    int
}

type SearchResult struct {
	ID         string
	Score      float64
	Payload    map[string]any
	QuestionID int64
}

func NewClient(cfg config.VectorConfig) *Client {
	timeout := time.Duration(cfg.TimeoutSeconds) * time.Second
	if timeout <= 0 {
		timeout = 30 * time.Second
	}

	return &Client{
		baseURL:        strings.TrimRight(strings.TrimSpace(cfg.QdrantURL), "/"),
		apiKey:         strings.TrimSpace(cfg.APIKey),
		collectionName: strings.TrimSpace(cfg.CollectionName),
		distance:       strings.TrimSpace(cfg.Distance),
		httpClient: &http.Client{
			Timeout: timeout,
		},
	}
}

func (c *Client) EnsureCollection(ctx context.Context, vectorSize int) error {
	if vectorSize <= 0 {
		return fmt.Errorf("invalid vector size: %d", vectorSize)
	}

	c.mu.Lock()
	defer c.mu.Unlock()

	if c.ensuredSize == vectorSize {
		return nil
	}

	size, exists, err := c.collectionVectorSize(ctx)
	if err != nil {
		return err
	}
	if !exists {
		if err := c.createCollection(ctx, vectorSize); err != nil {
			return err
		}
		c.ensuredSize = vectorSize
		return nil
	}
	if size != vectorSize {
		return fmt.Errorf("qdrant collection vector size mismatch: existing=%d expected=%d", size, vectorSize)
	}

	c.ensuredSize = vectorSize
	return nil
}

func (c *Client) UpsertPoint(ctx context.Context, pointID string, vector []float64, payload map[string]any) error {
	body := map[string]any{
		"points": []map[string]any{
			{
				"id":      pointID,
				"vector":  vector,
				"payload": payload,
			},
		},
	}
	return c.doJSON(ctx, http.MethodPut, "/collections/"+c.collectionName+"/points", body, nil, http.StatusOK, http.StatusAccepted)
}

func (c *Client) SetPayload(ctx context.Context, pointIDs []string, payload map[string]any) error {
	if len(pointIDs) == 0 {
		return nil
	}

	body := map[string]any{
		"payload": payload,
		"points":  pointIDs,
	}
	return c.doJSON(ctx, http.MethodPost, "/collections/"+c.collectionName+"/points/payload", body, nil, http.StatusOK, http.StatusAccepted)
}

func (c *Client) DeletePoints(ctx context.Context, pointIDs []string) error {
	if len(pointIDs) == 0 {
		return nil
	}

	body := map[string]any{
		"points": pointIDs,
	}
	return c.doJSON(ctx, http.MethodPost, "/collections/"+c.collectionName+"/points/delete", body, nil, http.StatusOK, http.StatusAccepted)
}

func (c *Client) Search(ctx context.Context, vector []float64, limit int, filter map[string]any) ([]SearchResult, error) {
	body := map[string]any{
		"vector":       vector,
		"limit":        limit,
		"with_payload": true,
	}
	if len(filter) > 0 {
		body["filter"] = filter
	}

	var response struct {
		Result []struct {
			ID      any            `json:"id"`
			Score   float64        `json:"score"`
			Payload map[string]any `json:"payload"`
		} `json:"result"`
	}
	if err := c.doJSON(ctx, http.MethodPost, "/collections/"+c.collectionName+"/points/search", body, &response, http.StatusOK); err != nil {
		return nil, err
	}

	results := make([]SearchResult, 0, len(response.Result))
	for _, item := range response.Result {
		result := SearchResult{
			ID:      fmt.Sprint(item.ID),
			Score:   item.Score,
			Payload: item.Payload,
		}
		result.QuestionID = extractQuestionID(item.Payload["question_id"])
		results = append(results, result)
	}

	return results, nil
}

func (c *Client) collectionVectorSize(ctx context.Context) (int, bool, error) {
	var response map[string]any
	err := c.doJSON(ctx, http.MethodGet, "/collections/"+c.collectionName, nil, &response, http.StatusOK, http.StatusNotFound)
	if err != nil {
		return 0, false, err
	}
	if response["result"] == nil {
		return 0, false, nil
	}
	status, _ := response["status"].(string)
	if status == "error" {
		return 0, false, fmt.Errorf("qdrant collection query failed")
	}
	if result, ok := response["result"].(map[string]any); ok {
		if configMap, ok := result["config"].(map[string]any); ok {
			if params, ok := configMap["params"].(map[string]any); ok {
				if vectors, ok := params["vectors"].(map[string]any); ok {
					if size, ok := extractNumber(vectors["size"]); ok {
						return size, true, nil
					}
				}
			}
		}
	}
	return 0, true, fmt.Errorf("unable to parse qdrant collection vector size")
}

func (c *Client) createCollection(ctx context.Context, vectorSize int) error {
	distance := c.distance
	if distance == "" {
		distance = "Cosine"
	}

	body := map[string]any{
		"vectors": map[string]any{
			"size":     vectorSize,
			"distance": distance,
		},
	}
	return c.doJSON(ctx, http.MethodPut, "/collections/"+c.collectionName, body, nil, http.StatusOK, http.StatusAccepted)
}

func (c *Client) doJSON(ctx context.Context, method, path string, requestBody any, responseBody any, successCodes ...int) error {
	if c.baseURL == "" {
		return fmt.Errorf("qdrant url is required")
	}
	if c.collectionName == "" {
		return fmt.Errorf("qdrant collection_name is required")
	}

	var bodyReader io.Reader
	if requestBody != nil {
		payload, err := json.Marshal(requestBody)
		if err != nil {
			return fmt.Errorf("marshal qdrant request: %w", err)
		}
		bodyReader = bytes.NewReader(payload)
	}

	req, err := http.NewRequestWithContext(ctx, method, c.baseURL+path, bodyReader)
	if err != nil {
		return fmt.Errorf("create qdrant request: %w", err)
	}
	if c.apiKey != "" {
		req.Header.Set("api-key", c.apiKey)
	}
	if requestBody != nil {
		req.Header.Set("Content-Type", "application/json")
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("qdrant http call: %w", err)
	}
	defer resp.Body.Close()

	for _, code := range successCodes {
		if resp.StatusCode == code {
			if responseBody != nil {
				if err := json.NewDecoder(resp.Body).Decode(responseBody); err != nil && err != io.EOF {
					return fmt.Errorf("decode qdrant response: %w", err)
				}
			}
			return nil
		}
	}

	body, _ := io.ReadAll(resp.Body)
	return fmt.Errorf("qdrant returned status %d: %s", resp.StatusCode, strings.TrimSpace(string(body)))
}

func extractNumber(value any) (int, bool) {
	switch v := value.(type) {
	case float64:
		return int(v), true
	case int:
		return v, true
	case int64:
		return int(v), true
	case json.Number:
		i, err := v.Int64()
		if err != nil {
			return 0, false
		}
		return int(i), true
	case string:
		i, err := strconv.Atoi(v)
		if err != nil {
			return 0, false
		}
		return i, true
	default:
		return 0, false
	}
}

func extractQuestionID(value any) int64 {
	switch v := value.(type) {
	case float64:
		return int64(v)
	case int64:
		return v
	case int:
		return int64(v)
	case string:
		parsed, err := strconv.ParseInt(v, 10, 64)
		if err != nil {
			return 0
		}
		return parsed
	default:
		return 0
	}
}
