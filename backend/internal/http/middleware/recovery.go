package middleware

import (
	"log/slog"
	"net/http"
	"runtime/debug"

	"mathnotebook/backend/internal/domain/dto"
)

func Recovery(appLogger *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			defer func() {
				if rec := recover(); rec != nil {
					appLogger.Error("panic recovered", "panic", rec, "stack", string(debug.Stack()))
					dto.WriteJSON(w, http.StatusInternalServerError, dto.Response{
						Code:    50000,
						Message: "internal server error",
						Data:    nil,
					})
				}
			}()

			next.ServeHTTP(w, r)
		})
	}
}
