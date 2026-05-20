package v1

import (
	"net/http"

	"mathnotebook/backend/internal/domain/dto"
	"mathnotebook/backend/internal/service"
)

type UserHandler struct {
	service *service.UserService
}

func NewUserHandler(service *service.UserService) *UserHandler {
	return &UserHandler{service: service}
}

func (h *UserHandler) GetMe(w http.ResponseWriter, r *http.Request) {
	resp, err := h.service.GetMe(r.Context())
	if err != nil {
		dto.HandleError(w, err)
		return
	}

	dto.WriteSuccess(w, resp)
}
