package middleware

import (
	"net/http"
	"strings"

	"mathnotebook/backend/internal/domain/dto"
	apperrors "mathnotebook/backend/internal/pkg/errors"
	"mathnotebook/backend/internal/service"
)

var errMissingToken = apperrors.New(http.StatusUnauthorized, 40100, "缺少认证令牌")

var publicPaths = map[string]bool{
	"/healthz":                          true,
	"/docs":                             true,
	"/docs/openapi.json":                true,
	"/api/v1/auth/register":             true,
	"/api/v1/auth/login":                true,
	"/api/v1/mobile/latest-version":     true,
}

func Auth(authService *service.AuthService) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if isPublicPath(r.URL.Path) {
				next.ServeHTTP(w, r)
				return
			}

			tokenString, ok := readBearerToken(r)
			if !ok || tokenString == "" {
				dto.HandleError(w, errMissingToken)
				return
			}

			userID, err := authService.ValidateJWT(tokenString)
			if err != nil {
				dto.HandleError(w, err)
				return
			}

			ctx := service.SetUserID(r.Context(), userID)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

func readBearerToken(r *http.Request) (string, bool) {
	authHeader := r.Header.Get("Authorization")
	if authHeader != "" {
		tokenString, ok := strings.CutPrefix(authHeader, "Bearer ")
		if ok && tokenString != "" {
			return tokenString, true
		}
	}

	if r.Method == http.MethodGet && r.URL.Path == "/api/v1/wrong-questions/export/print" {
		tokenString := strings.TrimSpace(r.URL.Query().Get("access_token"))
		if tokenString != "" {
			return tokenString, true
		}
	}

	return "", false
}

func isPublicPath(path string) bool {
	if len(path) > 1 && path[len(path)-1] == '/' {
		path = path[:len(path)-1]
	}
	return publicPaths[path]
}
