package validator

import (
	"strings"

	apperrors "mathnotebook/backend/internal/pkg/errors"
)

func RequireString(value, field string) error {
	if strings.TrimSpace(value) == "" {
		return apperrors.New(400, 40001, field+" 不能为空")
	}

	return nil
}

func AllowEnum(value, field string, valid func(string) bool) error {
	if strings.TrimSpace(value) == "" {
		return nil
	}

	if !valid(value) {
		return apperrors.New(400, 40001, field+" 不合法")
	}

	return nil
}

func Difficulty(value int) error {
	if value == 0 {
		return nil
	}

	if value < 1 || value > 5 {
		return apperrors.New(400, 40001, "difficulty_level 必须在 1-5 之间")
	}

	return nil
}
