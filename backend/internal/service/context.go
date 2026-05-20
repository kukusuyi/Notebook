package service

import (
	"context"
	"net/http"

	apperrors "mathnotebook/backend/internal/pkg/errors"
)

type contextKey string

const userIDContextKey contextKey = "userID"

func SetUserID(ctx context.Context, userID int64) context.Context {
	return context.WithValue(ctx, userIDContextKey, userID)
}

func GetUserID(ctx context.Context) (int64, bool) {
	id, ok := ctx.Value(userIDContextKey).(int64)
	return id, ok
}

func RequireUserID(ctx context.Context) (int64, error) {
	userID, ok := GetUserID(ctx)
	if !ok || userID <= 0 {
		return 0, apperrors.New(http.StatusUnauthorized, 40100, "未获取到用户信息")
	}

	return userID, nil
}
