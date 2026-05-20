package dto

import (
	"encoding/json"
	"errors"
	"net/http"

	apperrors "mathnotebook/backend/internal/pkg/errors"
)

type Response struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
	Data    any    `json:"data"`
}

type PageResult[T any] struct {
	List     []T `json:"list"`
	Total    int `json:"total"`
	Page     int `json:"page"`
	PageSize int `json:"page_size"`
}

func WriteSuccess(w http.ResponseWriter, data any) {
	WriteJSON(w, http.StatusOK, Response{
		Code:    0,
		Message: "success",
		Data:    data,
	})
}

func HandleError(w http.ResponseWriter, err error) {
	var appErr *apperrors.AppError
	if errors.As(err, &appErr) {
		WriteJSON(w, appErr.Status, Response{
			Code:    appErr.Code,
			Message: appErr.Message,
			Data:    nil,
		})
		return
	}

	WriteJSON(w, http.StatusInternalServerError, Response{
		Code:    50000,
		Message: "internal server error",
		Data:    nil,
	})
}

func WriteJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

func DecodeJSON(r *http.Request, target any) error {
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()

	if err := decoder.Decode(target); err != nil {
		return apperrors.New(http.StatusBadRequest, 40001, "参数错误: 无法解析请求体")
	}

	return nil
}
