package service

import (
	"context"
	"strings"
	"testing"

	"github.com/kukusuyi/Questrace/backend/internal/domain/dto"
)

func TestSolutionOCROnlyReturnsAnswer(t *testing.T) {
	c := &stubOCRClient{response: `{"question_core":"do not apply","wrong_solution":"do not apply","standard_solution":"步骤一","ocr_confidence":"high","uncertain_parts":[]}`}
	s, err := NewOCRService(c, 0)
	if err != nil {
		t.Fatal(err)
	}
	r, err := s.Recognize(context.Background(), dto.OCRWrongQuestionRequest{ImageID: 1, ImageURL: "data:image/png;base64,AA==", Purpose: "solution"})
	if err != nil {
		t.Fatal(err)
	}
	if r.StandardSolution != "步骤一" || r.QuestionCore != "" || r.WrongSolution != "" {
		t.Fatalf("unexpected result %+v", r)
	}
	if len(c.prompts) != 1 || !strings.Contains(c.prompts[0], "standard_solution") {
		t.Fatal("missing answer prompt")
	}
}
func TestSolutionOCRRejectsMalformedResponseAndUnknownPurpose(t *testing.T) {
	c := &stubOCRClient{response: "raw provider text"}
	s, _ := NewOCRService(c, 0)
	_, err := s.Recognize(context.Background(), dto.OCRWrongQuestionRequest{ImageID: 1, ImageURL: "image", Purpose: "solution"})
	if err == nil || strings.Contains(err.Error(), "raw provider") {
		t.Fatal("must reject malformed answer without raw data")
	}
	_, err = s.Recognize(context.Background(), dto.OCRWrongQuestionRequest{ImageID: 1, ImageURL: "image", Purpose: "invalid"})
	if err == nil || len(c.prompts) != 1 {
		t.Fatal("invalid purpose called provider")
	}
}
