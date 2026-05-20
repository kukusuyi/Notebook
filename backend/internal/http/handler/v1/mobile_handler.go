package v1

import (
	"net/http"

	"mathnotebook/backend/internal/domain/dto"
	"mathnotebook/backend/internal/service"
)

type MobileHandler struct {
	service *service.MobileService
}

func NewMobileHandler(service *service.MobileService) *MobileHandler {
	return &MobileHandler{service: service}
}

func (h *MobileHandler) GetLatestVersion(w http.ResponseWriter, r *http.Request) {
	resp := h.service.GetLatestVersion()
	dto.WriteSuccess(w, resp)
}
