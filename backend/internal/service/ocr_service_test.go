package service

import (
	"context"
	"os"
	"path/filepath"
	"testing"

	"mathnotebook/backend/internal/domain/dto"
)

const testOCRJSONResponse = `{
  "question_core": "题目",
  "standard_solution": "",
  "wrong_solution": "",
  "uncertain_parts": [],
  "ocr_confidence": "medium"
}`

type stubOCRClient struct {
	response string
	prompts  []string
}

func (c *stubOCRClient) Recognize(_ context.Context, _ string, prompt string) (string, error) {
	c.prompts = append(c.prompts, prompt)
	return c.response, nil
}

func TestOCRServiceRecognizeUsesLatestPromptFile(t *testing.T) {
	originalWD, err := os.Getwd()
	if err != nil {
		t.Fatalf("getwd: %v", err)
	}
	defer func() {
		_ = os.Chdir(originalWD)
	}()

	tempDir := t.TempDir()
	if err := os.Chdir(tempDir); err != nil {
		t.Fatalf("chdir temp dir: %v", err)
	}

	promptPath := filepath.Join(tempDir, "ocr_prompt.md")
	if err := os.MkdirAll(filepath.Dir(promptPath), 0o755); err != nil {
		t.Fatalf("mkdir prompt dir: %v", err)
	}
	if err := os.WriteFile(promptPath, []byte("prompt-v1"), 0o644); err != nil {
		t.Fatalf("write prompt v1: %v", err)
	}

	client := &stubOCRClient{response: testOCRJSONResponse}
	service := &OCRService{
		client:     client,
		promptText: "startup-prompt",
	}

	req := dto.OCRWrongQuestionRequest{
		ImageID:  1,
		ImageURL: "https://example.com/math.jpg",
	}

	if _, err := service.Recognize(context.Background(), req); err != nil {
		t.Fatalf("first recognize: %v", err)
	}

	if got := client.prompts[0]; got != "prompt-v1" {
		t.Fatalf("first prompt = %q, want %q", got, "prompt-v1")
	}

	if err := os.WriteFile(promptPath, []byte("prompt-v2"), 0o644); err != nil {
		t.Fatalf("write prompt v2: %v", err)
	}

	if _, err := service.Recognize(context.Background(), req); err != nil {
		t.Fatalf("second recognize: %v", err)
	}

	if got := client.prompts[1]; got != "prompt-v2" {
		t.Fatalf("second prompt = %q, want %q", got, "prompt-v2")
	}
}

func TestOCRServiceRecognizeFallsBackToStartupPromptWhenPromptFileIsEmpty(t *testing.T) {
	originalWD, err := os.Getwd()
	if err != nil {
		t.Fatalf("getwd: %v", err)
	}
	defer func() {
		_ = os.Chdir(originalWD)
	}()

	tempDir := t.TempDir()
	if err := os.Chdir(tempDir); err != nil {
		t.Fatalf("chdir temp dir: %v", err)
	}

	promptPath := filepath.Join(tempDir, "ocr_prompt.md")
	if err := os.MkdirAll(filepath.Dir(promptPath), 0o755); err != nil {
		t.Fatalf("mkdir prompt dir: %v", err)
	}
	if err := os.WriteFile(promptPath, []byte("   \n"), 0o644); err != nil {
		t.Fatalf("write empty prompt: %v", err)
	}

	client := &stubOCRClient{response: testOCRJSONResponse}
	service := &OCRService{
		client:     client,
		promptText: "startup-prompt",
	}

	_, err = service.Recognize(context.Background(), dto.OCRWrongQuestionRequest{
		ImageID:  1,
		ImageURL: "https://example.com/math.jpg",
	})
	if err != nil {
		t.Fatalf("recognize with fallback prompt: %v", err)
	}

	if got := client.prompts[0]; got != "startup-prompt" {
		t.Fatalf("fallback prompt = %q, want %q", got, "startup-prompt")
	}
}

func TestParseOCRResultReclassifiesWrongSolutionWhenModelWritesCorrectnessAnalysis(t *testing.T) {
	raw := `{
  "question_core": "题目",
  "standard_solution": "",
  "wrong_solution": "这是原本被模型放进 wrong_solution 的解题过程",
  "uncertain_parts": [
    "图片中解题过程未明确标注对错，但根据数学推导逻辑，该过程及结论均为正确，实际应视为正确解法。"
  ],
  "ocr_confidence": "medium"
}`

	result, err := parseOCRResult(raw)
	if err != nil {
		t.Fatalf("parse ocr result: %v", err)
	}

	if result.WrongSolution != "" {
		t.Fatalf("wrong_solution = %q, want empty", result.WrongSolution)
	}
	if result.StandardSolution != "这是原本被模型放进 wrong_solution 的解题过程" {
		t.Fatalf("standard_solution = %q", result.StandardSolution)
	}
	if len(result.UncertainParts) != 1 {
		t.Fatalf("uncertain_parts len = %d", len(result.UncertainParts))
	}
	if result.UncertainParts[0] != "模型对该解题过程做了越界正确性说明，已降级为人工复核提示" {
		t.Fatalf("unexpected uncertain_part = %q", result.UncertainParts[0])
	}
}
