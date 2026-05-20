package v1

import (
	"net/http"

	"mathnotebook/backend/internal/domain/dto"
	"mathnotebook/backend/internal/service"
)

type AIHandler struct {
	service *service.AIService
}

func NewAIHandler(service *service.AIService) *AIHandler {
	return &AIHandler{service: service}
}

func (h *AIHandler) AnalyzeWrongQuestion(w http.ResponseWriter, r *http.Request) {
	var req dto.AnalyzeWrongQuestionRequest
	if err := dto.DecodeJSON(r, &req); err != nil {
		dto.HandleError(w, err)
		return
	}

	response, err := h.service.Analyze(r.Context(), req)
	if err != nil {
		dto.HandleError(w, err)
		return
	}

	dto.WriteSuccess(w, response)
}

func (h *AIHandler) ListProviders(w http.ResponseWriter, r *http.Request) {
	dto.WriteSuccess(w, h.service.ListProviders())
}

func (h *AIHandler) ListProviderModels(w http.ResponseWriter, r *http.Request) {
	providerName := r.PathValue("providerName")

	response, err := h.service.ListProviderModels(r.Context(), providerName)
	if err != nil {
		dto.HandleError(w, err)
		return
	}

	dto.WriteSuccess(w, response)
}

func (h *AIHandler) ListChapters(w http.ResponseWriter, r *http.Request) {
	response, err := h.service.ListChapters()
	if err != nil {
		dto.HandleError(w, err)
		return
	}

	dto.WriteSuccess(w, response)
}
