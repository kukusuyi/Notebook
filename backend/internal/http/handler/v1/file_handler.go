package v1

import (
	"net/http"
	"strings"

	"mathnotebook/backend/internal/domain/dto"
	"mathnotebook/backend/internal/service"
)

type FileHandler struct {
	service *service.FileService
}

func NewFileHandler(service *service.FileService) *FileHandler {
	return &FileHandler{service: service}
}

func (h *FileHandler) UploadImage(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseMultipartForm(16 << 20); err != nil {
		dto.HandleError(w, err)
		return
	}

	file, header, err := r.FormFile("file")
	if err != nil {
		dto.HandleError(w, err)
		return
	}
	defer file.Close()

	response, err := h.service.Upload(
		r.Context(),
		file,
		header,
		requestScheme(r),
		requestHost(r),
	)
	if err != nil {
		dto.HandleError(w, err)
		return
	}

	dto.WriteSuccess(w, response)
}

func requestScheme(r *http.Request) string {
	if r == nil {
		return "http"
	}

	if forwarded := strings.TrimSpace(r.Header.Get("X-Forwarded-Proto")); forwarded != "" {
		return forwarded
	}
	if r.TLS != nil {
		return "https"
	}
	return "http"
}

func requestHost(r *http.Request) string {
	if r == nil {
		return ""
	}

	if forwarded := strings.TrimSpace(r.Header.Get("X-Forwarded-Host")); forwarded != "" {
		return forwarded
	}
	return strings.TrimSpace(r.Host)
}
