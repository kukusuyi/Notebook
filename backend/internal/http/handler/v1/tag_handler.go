package v1

import (
	"net/http"
	"strconv"

	"mathnotebook/backend/internal/domain/dto"
	apperrors "mathnotebook/backend/internal/pkg/errors"
	"mathnotebook/backend/internal/service"
)

type TagHandler struct {
	service *service.TagService
}

func NewTagHandler(service *service.TagService) *TagHandler {
	return &TagHandler{service: service}
}

func (h *TagHandler) List(w http.ResponseWriter, r *http.Request) {
	response, err := h.service.List(r.Context(), r.URL.Query().Get("tag_type"), r.URL.Query().Get("keyword"))
	if err != nil {
		dto.HandleError(w, err)
		return
	}

	dto.WriteSuccess(w, response)
}

func (h *TagHandler) Create(w http.ResponseWriter, r *http.Request) {
	var req dto.CreateTagRequest
	if err := dto.DecodeJSON(r, &req); err != nil {
		dto.HandleError(w, err)
		return
	}

	response, err := h.service.Create(r.Context(), req)
	if err != nil {
		dto.HandleError(w, err)
		return
	}

	dto.WriteSuccess(w, response)
}

func (h *TagHandler) Delete(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(r.PathValue("tagID"), 10, 64)
	if err != nil || id <= 0 {
		dto.HandleError(w, apperrors.New(http.StatusBadRequest, 40001, "路径参数不合法"))
		return
	}

	if err := h.service.Delete(r.Context(), id); err != nil {
		dto.HandleError(w, err)
		return
	}

	dto.WriteSuccess(w, dto.DeleteTagResponse{
		TagID:   id,
		Deleted: true,
	})
}
