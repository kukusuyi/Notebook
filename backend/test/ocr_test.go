package test

import (
	"testing"

	"mathnotebook/backend/internal/domain/dto"
)

func TestOCRIntegration(t *testing.T) {
	// 填写测试图片的url
	// 例如: http://localhost:9001/api/v1/download-shared-object/your-test-image
	imageURL := ""
	if imageURL == "" {
		t.Skip("TEST_OCR_IMAGE_URL not set (set to a math problem image URL)")
	}

	token := ensureToken(t)

	resp, body, err := doPost(baseURL+"/api/v1/ocr/wrong-question-json", token, map[string]any{
		"image_url": imageURL,
		"image_id":  1,
	})
	if err != nil {
		t.Fatalf("ocr request: %v", err)
	}

	if resp.StatusCode == 503 {
		apiResp, _ := parseResponse(body)
		if apiResp.Code == 50002 {
			t.Skip("OCR not configured (no API key), skipping integration test: " + apiResp.Message)
		}
	}

	if resp.StatusCode == 500 {
		apiResp, _ := parseResponse(body)
		t.Skip("OCR API not available: " + apiResp.Message)
	}

	if resp.StatusCode != 200 {
		t.Fatalf("ocr status=%d body=%s", resp.StatusCode, string(body))
	}

	result, err := unmarshalData[dto.OCRWrongQuestionResponse](body)
	if err != nil {
		t.Fatalf("parse response: %v (body: %s)", err, string(body))
	}

	if result.QuestionCore == "" {
		t.Error("question_core should not be empty")
	} else {
		t.Logf("question_core: %s", result.QuestionCore)
	}

	t.Logf("standard_solution: %s", result.StandardSolution)
	t.Logf("wrong_solution: %s", result.WrongSolution)
	t.Logf("ocr_confidence: %s", result.OCRConfidence)
	t.Logf("uncertain_parts: %v", result.UncertainParts)

	validConfidence := result.OCRConfidence == "high" || result.OCRConfidence == "medium" || result.OCRConfidence == "low"
	if !validConfidence {
		t.Errorf("ocr_confidence should be high/medium/low, got %s", result.OCRConfidence)
	}
}
