package ai

import (
	"context"
	"fmt"
	"os"
	"testing"

	"github.com/kukusuyi/Questrace/backend/internal/config"
)

func TestEmbeddingClient(t *testing.T) {
	cfg := config.Config{EmbeddingModel: config.EmbeddingModelConfig{ProviderType: "openai_compatible", BaseURL: os.Getenv("EMBEDDING_BASE_URL"), Model: os.Getenv("EMBEDDING_MODEL"), APIKey: os.Getenv("EMBEDDING_API_KEY")}}
	if cfg.EmbeddingModel.APIKey == "" {
		t.Skip("live provider test: EMBEDDING_API_KEY not configured")
	}

	client, err := NewEmbeddingClient(cfg.EmbeddingModel)
	if err != nil {
		t.Fatalf("Failed to create embedding client: %v", err)
	}

	fmt.Printf("Provider: %s, Model: %s\n", cfg.EmbeddingModel.ProviderType, client.ModelName())

	ctx := context.Background()
	text := "你好，这是一个测试文本"

	vector, err := client.Embed(ctx, text)
	if err != nil {
		t.Fatalf("Embedding call failed: %v", err)
	}

	fmt.Printf("Input: %s\n", text)
	fmt.Printf("Vector dimension: %d\n", len(vector))
	fmt.Printf("First 5 values: %v\n", vector[:min(5, len(vector))])
}
