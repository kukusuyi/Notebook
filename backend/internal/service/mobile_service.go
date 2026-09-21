package service

import (
	"mathnotebook/backend/internal/config"
	"mathnotebook/backend/internal/domain/dto"
)

type MobileService struct {
	versionConfig config.MobileVersionConfig
	fileConfig    config.FileConfig
}

func NewMobileService(versionConfig config.MobileVersionConfig, fileConfig config.FileConfig) *MobileService {
	return &MobileService{
		versionConfig: versionConfig,
		fileConfig:    fileConfig,
	}
}

func (s *MobileService) GetLatestVersion() dto.MobileVersionResponse {
	apkURL := s.buildAPKURL()

	return dto.MobileVersionResponse{
		Version:           s.versionConfig.Version,
		APKUrl:            apkURL,
		ForceUpdate:       s.versionConfig.ForceUpdate,
		UpdateDescription: s.versionConfig.UpdateDescription,
	}
}

func (s *MobileService) buildAPKURL() string { return s.versionConfig.DownloadURL }
