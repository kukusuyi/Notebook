package test

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"sort"
	"strings"
	"sync"
)

type mockQdrantPoint struct {
	ID      string         `json:"id"`
	Vector  []float64      `json:"vector"`
	Payload map[string]any `json:"payload"`
}

type mockQdrantState struct {
	mu         sync.Mutex
	size       int
	collection bool
	points     map[string]mockQdrantPoint
}

func newMockQdrantServer() *httptest.Server {
	state := &mockQdrantState{
		points: make(map[string]mockQdrantPoint),
	}

	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch {
		case r.Method == http.MethodGet && r.URL.Path == "/collections/wrong_question_vectors":
			state.mu.Lock()
			defer state.mu.Unlock()
			if !state.collection {
				w.WriteHeader(http.StatusNotFound)
				_ = json.NewEncoder(w).Encode(map[string]any{"status": "error"})
				return
			}
			_ = json.NewEncoder(w).Encode(map[string]any{
				"result": map[string]any{
					"config": map[string]any{
						"params": map[string]any{
							"vectors": map[string]any{
								"size": state.size,
							},
						},
					},
				},
			})
		case r.Method == http.MethodPut && r.URL.Path == "/collections/wrong_question_vectors":
			var body struct {
				Vectors struct {
					Size int `json:"size"`
				} `json:"vectors"`
			}
			_ = json.NewDecoder(r.Body).Decode(&body)
			state.mu.Lock()
			state.collection = true
			state.size = body.Vectors.Size
			state.mu.Unlock()
			_ = json.NewEncoder(w).Encode(map[string]any{"status": "ok"})
		case r.Method == http.MethodPut && r.URL.Path == "/collections/wrong_question_vectors/points":
			var body struct {
				Points []mockQdrantPoint `json:"points"`
			}
			_ = json.NewDecoder(r.Body).Decode(&body)
			state.mu.Lock()
			for _, point := range body.Points {
				state.points[point.ID] = point
			}
			state.mu.Unlock()
			_ = json.NewEncoder(w).Encode(map[string]any{"status": "ok"})
		case r.Method == http.MethodPost && r.URL.Path == "/collections/wrong_question_vectors/points/payload":
			var body struct {
				Payload map[string]any `json:"payload"`
				Points  []string       `json:"points"`
			}
			_ = json.NewDecoder(r.Body).Decode(&body)
			state.mu.Lock()
			for _, id := range body.Points {
				point := state.points[id]
				point.Payload = body.Payload
				state.points[id] = point
			}
			state.mu.Unlock()
			_ = json.NewEncoder(w).Encode(map[string]any{"status": "ok"})
		case r.Method == http.MethodPost && r.URL.Path == "/collections/wrong_question_vectors/points/delete":
			var body struct {
				Points []string `json:"points"`
			}
			_ = json.NewDecoder(r.Body).Decode(&body)
			state.mu.Lock()
			for _, id := range body.Points {
				delete(state.points, id)
			}
			state.mu.Unlock()
			_ = json.NewEncoder(w).Encode(map[string]any{"status": "ok"})
		case r.Method == http.MethodPost && r.URL.Path == "/collections/wrong_question_vectors/points/search":
			var body struct {
				Limit  int            `json:"limit"`
				Filter map[string]any `json:"filter"`
			}
			_ = json.NewDecoder(r.Body).Decode(&body)

			state.mu.Lock()
			points := make([]mockQdrantPoint, 0, len(state.points))
			for _, point := range state.points {
				if matchesMockQdrantFilter(point.Payload, body.Filter) {
					points = append(points, point)
				}
			}
			state.mu.Unlock()

			sort.Slice(points, func(i, j int) bool {
				return points[i].ID < points[j].ID
			})
			if body.Limit > 0 && len(points) > body.Limit {
				points = points[:body.Limit]
			}

			result := make([]map[string]any, 0, len(points))
			score := 0.95
			for _, point := range points {
				result = append(result, map[string]any{
					"id":      point.ID,
					"score":   score,
					"payload": point.Payload,
				})
				score -= 0.01
			}
			_ = json.NewEncoder(w).Encode(map[string]any{"result": result})
		default:
			http.NotFound(w, r)
		}
	}))
}

func matchesMockQdrantFilter(payload map[string]any, filter map[string]any) bool {
	if len(filter) == 0 {
		return true
	}

	rawMust, ok := filter["must"].([]any)
	if !ok {
		return true
	}
	for _, raw := range rawMust {
		condition, ok := raw.(map[string]any)
		if !ok {
			continue
		}
		key, _ := condition["key"].(string)
		match, _ := condition["match"].(map[string]any)
		value := payload[key]
		if expected, ok := match["value"]; ok {
			if value != expected {
				return false
			}
		}
		if expectedAny, ok := match["any"].([]any); ok {
			if !matchesAnyValue(value, expectedAny) {
				return false
			}
		}
	}

	return true
}

func matchesAnyValue(value any, expected []any) bool {
	items, ok := value.([]any)
	if ok {
		for _, item := range items {
			if containsAny(expected, item) {
				return true
			}
		}
		return false
	}
	if items, ok := value.([]string); ok {
		for _, item := range items {
			if containsStringAny(expected, item) {
				return true
			}
		}
		return false
	}
	return containsAny(expected, value)
}

func containsAny(values []any, target any) bool {
	for _, value := range values {
		if value == target {
			return true
		}
		if asString, ok := value.(string); ok && strings.TrimSpace(asString) == strings.TrimSpace(toString(target)) {
			return true
		}
	}
	return false
}

func containsStringAny(values []any, target string) bool {
	for _, value := range values {
		if asString, ok := value.(string); ok && asString == target {
			return true
		}
	}
	return false
}

func toString(value any) string {
	return strings.TrimSpace(fmt.Sprint(value))
}
