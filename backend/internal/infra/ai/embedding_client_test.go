package ai

import (
	"context"
	"fmt"
	"os"
	"testing"

	"mathnotebook/backend/internal/config"
)

func TestEmbeddingClient(t *testing.T) {
	if err := os.Setenv("CONFIG_PATH", "../../../configs/config.yaml"); err != nil {
		t.Fatalf("Failed to set CONFIG_PATH: %v", err)
	}

	cfg := config.Load()

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
