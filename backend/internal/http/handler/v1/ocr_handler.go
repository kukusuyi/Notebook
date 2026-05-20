package v1

import (
	"net/http"

	"mathnotebook/backend/internal/domain/dto"
	"mathnotebook/backend/internal/service"
)

type OCRHandler struct {
	service *service.OCRService
}

func NewOCRHandler(service *service.OCRService) *OCRHandler {
	return &OCRHandler{service: service}
}

func (h *OCRHandler) RecognizeWrongQuestion(w http.ResponseWriter, r *http.Request) {
	var req dto.OCRWrongQuestionRequest
	if err := dto.DecodeJSON(r, &req); err != nil {
		dto.HandleError(w, err)
		return
	}

	response, err := h.service.Recognize(r.Context(), req)
	if err != nil {
		dto.HandleError(w, err)
		return
	}

	dto.WriteSuccess(w, response)
}
