package service

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"strings"

	"mathnotebook/backend/internal/domain/dto"
	ocrclient "mathnotebook/backend/internal/infra/ocr"
	apperrors "mathnotebook/backend/internal/pkg/errors"
	"mathnotebook/backend/internal/pkg/validator"
)

const ocrPromptRelativePath = "ocr_prompt.md"

type ocrRawResult struct {
	QuestionCore     string   `json:"question_core"`
	StandardSolution string   `json:"standard_solution"`
	WrongSolution    string   `json:"wrong_solution"`
	UncertainParts   []string `json:"uncertain_parts"`
	OCRConfidence    string   `json:"ocr_confidence"`
}

type OCRService struct {
	client        ocrclient.OCRClient
	defaultUserID int64
	promptText    string
}

func NewOCRService(client ocrclient.OCRClient, defaultUserID int64) (*OCRService, error) {
	promptText, err := loadOCRPrompt()
	if err != nil {
		return nil, err
	}
	return &OCRService{client: client, defaultUserID: defaultUserID, promptText: promptText}, nil
}

func (s *OCRService) Recognize(ctx context.Context, req dto.OCRWrongQuestionRequest) (dto.OCRWrongQuestionResponse, error) {
	if err := validator.RequireString(req.ImageURL, "image_url"); err != nil {
		return dto.OCRWrongQuestionResponse{}, err
	}
	if req.ImageID <= 0 {
		return dto.OCRWrongQuestionResponse{}, apperrors.New(http.StatusBadRequest, 40001, "image_id 必须大于 0")
	}

	if s.client == nil {
		return dto.OCRWrongQuestionResponse{}, apperrors.New(http.StatusServiceUnavailable, 50002, "OCR 服务未配置 API Key")
	}

	rawJSON, err := s.client.Recognize(ctx, req.ImageURL, s.currentPrompt())
	if err != nil {
		return dto.OCRWrongQuestionResponse{}, apperrors.New(http.StatusInternalServerError, 50003, "OCR 识别失败: "+err.Error())
	}

	result, parseErr := parseOCRResult(rawJSON)
	if parseErr != nil {
		return dto.OCRWrongQuestionResponse{
			QuestionCore:   rawJSON,
			OCRConfidence:  "low",
			UncertainParts: []string{"模型返回非 JSON 格式，请人工确认: " + parseErr.Error()},
		}, nil
	}

	return result, nil
}

func (s *OCRService) currentPrompt() string {
	promptText, err := loadOCRPrompt()
	if err == nil && strings.TrimSpace(promptText) != "" {
		return promptText
	}
	return s.promptText
}

func parseOCRResult(raw string) (dto.OCRWrongQuestionResponse, error) {
	cleaned := strings.TrimSpace(raw)
	cleaned = stripMarkdownJSON(cleaned)

	var ocrResp ocrRawResult
	if err := json.Unmarshal([]byte(cleaned), &ocrResp); err != nil {
		return dto.OCRWrongQuestionResponse{}, err
	}

	confidence := strings.ToLower(strings.TrimSpace(ocrResp.OCRConfidence))
	if confidence != "high" && confidence != "medium" && confidence != "low" {
		confidence = "medium"
	}

	standardSolution := strings.TrimSpace(ocrResp.StandardSolution)
	wrongSolution := strings.TrimSpace(ocrResp.WrongSolution)
	uncertainParts := normalizeOCRUncertainParts(ocrResp.UncertainParts)

	if shouldReclassifyWrongSolutionAsStandard(uncertainParts) && wrongSolution != "" {
		if standardSolution == "" {
			standardSolution = wrongSolution
		} else {
			standardSolution = strings.TrimSpace(standardSolution + "\n\n" + wrongSolution)
		}
		wrongSolution = ""
	}

	return dto.OCRWrongQuestionResponse{
		QuestionCore:     ocrResp.QuestionCore,
		StandardSolution: standardSolution,
		WrongSolution:    wrongSolution,
		OCRConfidence:    confidence,
		UncertainParts:   uncertainParts,
	}, nil
}

func normalizeOCRUncertainParts(parts []string) []string {
	if len(parts) == 0 {
		return []string{}
	}

	result := make([]string, 0, len(parts))
	seen := make(map[string]struct{}, len(parts))
	for _, item := range parts {
		normalized := normalizeOCRUncertainPart(item)
		if normalized == "" {
			continue
		}
		if _, ok := seen[normalized]; ok {
			continue
		}
		seen[normalized] = struct{}{}
		result = append(result, normalized)
	}

	if len(result) == 0 {
		return []string{}
	}

	return result
}

func normalizeOCRUncertainPart(part string) string {
	part = strings.TrimSpace(part)
	if part == "" {
		return ""
	}

	lower := strings.ToLower(part)
	if strings.Contains(part, "对错属性不明确") || strings.Contains(part, "无法判断") {
		return "该解题过程对错属性不明确，暂按正确题解归类"
	}
	if strings.Contains(lower, "according to") ||
		strings.Contains(part, "根据数学推导逻辑") ||
		strings.Contains(part, "根据推导逻辑") ||
		strings.Contains(part, "均为正确") ||
		strings.Contains(part, "结论") && strings.Contains(part, "正确") ||
		strings.Contains(part, "实际应视为正确解法") ||
		strings.Contains(part, "正确解法") ||
		strings.Contains(part, "泰勒展开") ||
		strings.Contains(part, "\\ln") {
		return "模型对该解题过程做了越界正确性说明，已降级为人工复核提示"
	}

	return part
}

func shouldReclassifyWrongSolutionAsStandard(uncertainParts []string) bool {
	for _, item := range uncertainParts {
		if strings.Contains(item, "暂按正确题解归类") || strings.Contains(item, "越界正确性说明") {
			return true
		}
	}
	return false
}

func loadOCRPrompt() (string, error) {
	candidates := ocrPromptPathCandidates()

	for _, candidate := range candidates {
		data, err := os.ReadFile(candidate)
		if err == nil {
			return string(data), nil
		}
	}

	return "", fmt.Errorf("read ocr prompt: file not found: %s", ocrPromptRelativePath)
}

func ocrPromptPathCandidates() []string {
	candidates := []string{
		ocrPromptRelativePath,
		filepath.Join("..", ocrPromptRelativePath),
		filepath.Join("..", "..", ocrPromptRelativePath),
	}

	if _, currentFile, _, ok := runtime.Caller(0); ok {
		candidates = append(candidates, filepath.Join(filepath.Dir(currentFile), "..", "..", ocrPromptRelativePath))
	}

	seen := make(map[string]struct{}, len(candidates))
	unique := make([]string, 0, len(candidates))
	for _, candidate := range candidates {
		candidate = filepath.Clean(candidate)
		if _, ok := seen[candidate]; ok {
			continue
		}
		seen[candidate] = struct{}{}
		unique = append(unique, candidate)
	}

	return unique
}

func stripMarkdownJSON(s string) string {
	if strings.HasPrefix(s, "```json") {
		s = strings.TrimPrefix(s, "```json")
		s = strings.TrimSpace(s)
		if strings.HasSuffix(s, "```") {
			s = strings.TrimSuffix(s, "```")
			s = strings.TrimSpace(s)
		}
	} else if strings.HasPrefix(s, "```") {
		s = strings.TrimPrefix(s, "```")
		s = strings.TrimSpace(s)
		if strings.HasSuffix(s, "```") {
			s = strings.TrimSuffix(s, "```")
			s = strings.TrimSpace(s)
		}
	}
	return s
}
