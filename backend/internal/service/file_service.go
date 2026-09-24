package service

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"mime"
	"mime/multipart"
	"net/http"
	"path/filepath"
	"strings"
	"time"

	"github.com/kukusuyi/Questrace/backend/internal/config"
	"github.com/kukusuyi/Questrace/backend/internal/domain/dto"
	"github.com/kukusuyi/Questrace/backend/internal/domain/model"
	apperrors "github.com/kukusuyi/Questrace/backend/internal/pkg/errors"
	"github.com/kukusuyi/Questrace/backend/internal/repository"
)

type FileService struct {
	repo    repository.FileRepository
	storage fileObjectStore
	config  config.FileConfig
	appEnv  string
}

type fileObjectStore interface {
	Upload(ctx context.Context, objectKey string, reader io.Reader, size int64, contentType string) (string, error)
}

func NewFileService(repo repository.FileRepository, storage fileObjectStore, cfg config.FileConfig, appEnv string) *FileService {
	return &FileService{
		repo:    repo,
		storage: storage,
		config:  cfg,
		appEnv:  strings.TrimSpace(appEnv),
	}
}

func (s *FileService) Upload(
	ctx context.Context,
	file multipart.File,
	fileHeader *multipart.FileHeader,
	requestScheme string,
	requestHost string,
) (dto.FileUploadResponse, error) {
	if file == nil || fileHeader == nil {
		return dto.FileUploadResponse{}, apperrors.New(http.StatusBadRequest, 40001, "file 不能为空")
	}
	userID, err := RequireUserID(ctx)
	if err != nil {
		return dto.FileUploadResponse{}, err
	}

	contentType, uploadReader, err := detectImageReader(file)
	if err != nil {
		return dto.FileUploadResponse{}, err
	}

	objectKey := fmt.Sprintf("wrong-question/%s%s", config.RandomSecret(), resolveObjectExt(fileHeader.Filename, contentType))
	fileURL, err := s.storage.Upload(ctx, objectKey, uploadReader, fileHeader.Size, contentType)
	if err != nil {
		return dto.FileUploadResponse{}, apperrors.New(http.StatusInternalServerError, 50001, "上传图片到对象存储失败")
	}

	record := model.FileRecord{
		UserID:          userID,
		StorageProvider: s.config.StorageProvider,
		BucketName:      s.config.DefaultBucket,
		ObjectKey:       objectKey,
		FileName:        fileHeader.Filename,
		FileURL:         fileURL,
		FileSize:        fileHeader.Size,
		MIMEType:        contentType,
		FileType:        "image",
		CreatedAt:       time.Now(),
	}

	created, err := s.repo.Create(record)
	if err != nil {
		return dto.FileUploadResponse{}, err
	}

	return dto.FileUploadResponse{
		ImageID:  created.ID,
		ImageURL: created.FileURL,
		FileName: created.FileName,
		FileSize: created.FileSize,
		MIMEType: created.MIMEType,
	}, nil
}

func (s *FileService) BindQuestion(ctx context.Context, imageID, questionID int64) error {
	userID, err := RequireUserID(ctx)
	if err != nil {
		return err
	}

	record, ok, err := s.repo.GetByID(imageID)
	if err != nil {
		return err
	}
	if !ok {
		return apperrors.New(http.StatusBadRequest, 40001, "source_image_id 不存在")
	}

	if record.UserID != userID {
		return apperrors.New(http.StatusForbidden, 40301, "无权绑定该图片")
	}

	return s.repo.BindQuestion(imageID, questionID)
}

func detectImageReader(file multipart.File) (string, io.Reader, error) {
	head := make([]byte, 512)
	n, err := file.Read(head)
	if err != nil && err != io.EOF {
		return "", nil, apperrors.New(http.StatusBadRequest, 40001, "读取上传文件失败")
	}
	if n == 0 {
		return "", nil, apperrors.New(http.StatusBadRequest, 40001, "上传文件不能为空")
	}

	contentType := http.DetectContentType(head[:n])
	if !strings.HasPrefix(contentType, "image/") {
		return "", nil, apperrors.New(http.StatusBadRequest, 40001, "仅支持上传图片文件")
	}

	return contentType, io.MultiReader(bytes.NewReader(head[:n]), file), nil
}

func resolveObjectExt(fileName, contentType string) string {
	if ext := strings.ToLower(filepath.Ext(fileName)); ext != "" {
		return ext
	}

	extensions, err := mime.ExtensionsByType(contentType)
	if err == nil && len(extensions) > 0 {
		return extensions[0]
	}

	return ".img"
}

func (s *FileService) OwnedImageURL(ctx context.Context, id int64) (string, error) {
	uid, err := RequireUserID(ctx)
	if err != nil {
		return "", err
	}
	rec, ok, err := s.repo.GetByID(id)
	if err != nil {
		return "", err
	}
	if !ok || rec.UserID != uid {
		return "", apperrors.New(404, 40401, "图片不存在")
	}
	return rec.FileURL, nil
}
