package v1

import (
	"net/http"

	"github.com/kukusuyi/Questrace/backend/internal/domain/dto"
	"github.com/kukusuyi/Questrace/backend/internal/pkg/session"
	"github.com/kukusuyi/Questrace/backend/internal/service"
)

type AuthHandler struct {
	service *service.AuthService
}

func NewAuthHandler(service *service.AuthService) *AuthHandler {
	return &AuthHandler{service: service}
}

func (h *AuthHandler) Register(w http.ResponseWriter, r *http.Request) {
	var req dto.RegisterRequest
	if err := dto.DecodeJSON(r, &req); err != nil {
		dto.HandleError(w, err)
		return
	}

	resp, err := h.service.Register(req)
	if err != nil {
		dto.HandleError(w, err)
		return
	}

	session.Set(w, r, resp.Token)
	dto.WriteSuccess(w, resp)
}

func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	var req dto.LoginRequest
	if err := dto.DecodeJSON(r, &req); err != nil {
		dto.HandleError(w, err)
		return
	}

	resp, err := h.service.Login(req)
	if err != nil {
		dto.HandleError(w, err)
		return
	}

	session.Set(w, r, resp.Token)
	dto.WriteSuccess(w, resp)
}
