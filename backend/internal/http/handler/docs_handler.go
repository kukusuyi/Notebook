package handler

import (
	"encoding/json"
	"net/http"

	"mathnotebook/backend/internal/openapi"
)

type DocsHandler struct {
	spec map[string]any
}

func NewDocsHandler(spec map[string]any) *DocsHandler {
	return &DocsHandler{spec: spec}
}

func (h *DocsHandler) OpenAPIJSON(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	_ = json.NewEncoder(w).Encode(h.spec)
}

func (h *DocsHandler) DocsPage(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	_, _ = w.Write([]byte(openapi.DocsHTML))
}
