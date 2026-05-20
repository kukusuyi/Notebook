package service

import (
	"context"
	"net/http"

	"mathnotebook/backend/internal/domain/dto"
	apperrors "mathnotebook/backend/internal/pkg/errors"
	"mathnotebook/backend/internal/repository"
)

type UserService struct {
	userRepo repository.UserRepository
}

func NewUserService(userRepo repository.UserRepository) *UserService {
	return &UserService{userRepo: userRepo}
}

func (s *UserService) GetMe(ctx context.Context) (dto.UserMeResponse, error) {
	userID, ok := GetUserID(ctx)
	if !ok {
		return dto.UserMeResponse{}, apperrors.New(http.StatusUnauthorized, 40100, "未获取到用户信息")
	}

	user, found, err := s.userRepo.GetByID(userID)
	if err != nil {
		return dto.UserMeResponse{}, err
	}
	if !found {
		return dto.UserMeResponse{}, apperrors.New(http.StatusNotFound, 40401, "用户不存在")
	}

	return dto.UserMeResponse{
		UserID:    user.ID,
		Username:  user.Username,
		Email:     user.Email,
		CreatedAt: user.CreatedAt.Format("2006-01-02T15:04:05Z"),
	}, nil
}
