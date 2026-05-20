package service

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"mime"
	"mime/multipart"
	"net"
	"net/http"
	"net/url"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"mathnotebook/backend/internal/config"
	"mathnotebook/backend/internal/domain/dto"
	"mathnotebook/backend/internal/domain/model"
	apperrors "mathnotebook/backend/internal/pkg/errors"
	"mathnotebook/backend/internal/repository"
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

	objectKey := fmt.Sprintf("wrong-question/%d%s", time.Now().UnixNano(), resolveObjectExt(fileHeader.Filename, contentType))
	fileURL, err := s.storage.Upload(ctx, objectKey, uploadReader, fileHeader.Size, contentType)
	if err != nil {
		return dto.FileUploadResponse{}, apperrors.New(http.StatusInternalServerError, 50001, "上传图片到对象存储失败")
	}
	fileURL = s.resolvePublicFileURL(fileURL, requestScheme, requestHost)

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

func (s *FileService) resolvePublicFileURL(rawURL, requestScheme, requestHost string) string {
	if !shouldAutoResolvePublicURL(s.appEnv, s.config) {
		return rawURL
	}

	trimmedHost := strings.TrimSpace(requestHost)
	if trimmedHost == "" {
		return rawURL
	}

	parsedURL, err := url.Parse(strings.TrimSpace(rawURL))
	if err != nil || parsedURL.Host == "" {
		return rawURL
	}

	if !isLoopbackHost(parsedURL.Hostname()) {
		return rawURL
	}

	hostName := hostWithoutPort(trimmedHost)
	if hostName == "" {
		return rawURL
	}

	if requestScheme != "" {
		parsedURL.Scheme = requestScheme
	}

	port := parsedURL.Port()
	if port != "" {
		parsedURL.Host = net.JoinHostPort(hostName, port)
	} else {
		parsedURL.Host = hostName
	}

	return parsedURL.String()
}

func shouldAutoResolvePublicURL(appEnv string, cfg config.FileConfig) bool {
	if !isDevelopmentEnv(appEnv) {
		return false
	}

	baseURL := strings.TrimSpace(cfg.PublicBaseURL())
	if baseURL == "" {
		return true
	}

	parsedURL, err := url.Parse(baseURL)
	if err != nil {
		return false
	}

	return isLoopbackHost(parsedURL.Hostname())
}

func isDevelopmentEnv(appEnv string) bool {
	switch strings.ToLower(strings.TrimSpace(appEnv)) {
	case "", "local", "dev", "development":
		return true
	default:
		return false
	}
}

func isLoopbackHost(host string) bool {
	trimmed := strings.TrimSpace(host)
	if trimmed == "" {
		return false
	}

	switch strings.ToLower(trimmed) {
	case "localhost", "127.0.0.1", "::1":
		return true
	}

	ip := net.ParseIP(trimmed)
	return ip != nil && ip.IsLoopback()
}

func hostWithoutPort(rawHost string) string {
	trimmed := strings.TrimSpace(rawHost)
	if trimmed == "" {
		return ""
	}

	if host, _, err := net.SplitHostPort(trimmed); err == nil {
		return host
	}

	if strings.Count(trimmed, ":") > 1 {
		return strings.Trim(trimmed, "[]")
	}

	if strings.Count(trimmed, ":") == 1 {
		if host, port, err := net.SplitHostPort(trimmed); err == nil && port != "" {
			return host
		}
		if _, err := strconv.Atoi(strings.Split(trimmed, ":")[1]); err == nil {
			return strings.Split(trimmed, ":")[0]
		}
	}

	return trimmed
}

func (s *FileService) BindQuestion(ctx context.Context, imageID, questionID int64) error {
	userID, err := RequireUserID(ctx)
	if err != nil {
		return err
	}

	record, ok := s.repo.GetByID(imageID)
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
