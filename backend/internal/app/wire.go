package app

import (
	"context"
	"database/sql"
	"log/slog"
	"net/http"

	"mathnotebook/backend/internal/config"
	httpx "mathnotebook/backend/internal/http"
	v1 "mathnotebook/backend/internal/http/handler/v1"
	aiinfra "mathnotebook/backend/internal/infra/ai"
	"mathnotebook/backend/internal/infra/ocr"
	"mathnotebook/backend/internal/infra/oss"
	qdrantinfra "mathnotebook/backend/internal/infra/qdrant"
	"mathnotebook/backend/internal/repository"
	"mathnotebook/backend/internal/service"
)

func BuildHTTPHandler(cfg config.Config, appLogger *slog.Logger, db *sql.DB) (http.Handler, error) {
	if err := ensureDefaultUser(db, cfg.DefaultUser); err != nil {
		return nil, err
	}

	questionRepo := repository.NewMySQLQuestionRepository(db)
	tagRepo := repository.NewMySQLTagRepository(db)
	fileRepo := repository.NewMySQLFileRepository(db)
	vectorRepo := repository.NewMySQLVectorRepository(db)

	userRepo := repository.NewMySQLUserRepository(db)
	aiAnalysisRecordRepo := repository.NewMySQLAIAnalysisRecordRepository(db)

	authService := service.NewAuthService(userRepo, cfg.JWT, cfg.Auth)
	userService := service.NewUserService(userRepo)
	tagService := service.NewTagService(tagRepo)
	dashboardService := service.NewDashboardService(questionRepo, tagRepo)
	objectStorage, err := oss.NewClient(cfg.File)
	if err != nil {
		return nil, err
	}
	if err := objectStorage.EnsureReady(context.Background()); err != nil {
		return nil, err
	}
	fileService := service.NewFileService(fileRepo, objectStorage, cfg.File, cfg.App.Env)
	var ocrClient ocr.OCRClient
	if cfg.ImageOcr.APIKey != "" {
		ocrClient = ocr.NewQwenOCRClientWithLogger(cfg.ImageOcr.APIKey, cfg.ImageOcr.Model, appLogger)
	}
	ocrService, err := service.NewOCRService(ocrClient, cfg.DefaultUser.ID)
	if err != nil {
		return nil, err
	}
	llmRegistry, err := aiinfra.NewRegistry(cfg.Models)
	if err != nil {
		return nil, err
	}
	aiService, err := service.NewAIService(
		llmRegistry,
		aiAnalysisRecordRepo,
		cfg.ImageOcr.Name,
		cfg.ImageOcr.Model,
	)
	if err != nil {
		return nil, err
	}
	embeddingClient, err := aiinfra.NewEmbeddingClient(cfg.EmbeddingModel)
	if err != nil {
		return nil, err
	}
	qdrantClient := qdrantinfra.NewClient(cfg.Vector)
	vectorService := service.NewVectorService(cfg.Vector, vectorRepo, embeddingClient, qdrantClient)
	questionService := service.NewQuestionService(questionRepo, fileService, tagService, vectorService)
	mobileService := service.NewMobileService(cfg.MobileVersion, cfg.File)

	handlers := httpx.V1Handlers{
		Auth:      v1.NewAuthHandler(authService),
		User:      v1.NewUserHandler(userService),
		Dashboard: v1.NewDashboardHandler(dashboardService),
		Tag:       v1.NewTagHandler(tagService),
		File:      v1.NewFileHandler(fileService),
		OCR:       v1.NewOCRHandler(ocrService),
		AI:        v1.NewAIHandler(aiService),
		Question:  v1.NewQuestionHandler(questionService),
		Mobile:    v1.NewMobileHandler(mobileService),
	}

	return httpx.NewRouter(appLogger, authService, handlers), nil
}
