package app

import (
	"github.com/kukusuyi/Questrace/backend/internal/domain/dto"
	"github.com/kukusuyi/Questrace/backend/internal/pkg/buildinfo"
	"github.com/kukusuyi/Questrace/backend/internal/service"
	"net/http"
	"runtime"
)

func (s *LocalRuntime) updates(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		fail(w, 405, "不支持此操作")
		return
	}
	info, err := service.Releases.Latest()
	if err != nil {
		fail(w, 502, err.Error())
		return
	}
	platform, arch := r.URL.Query().Get("platform"), r.URL.Query().Get("arch")
	if platform == "" {
		platform = runtime.GOOS
		arch = runtime.GOARCH
	}
	if r.URL.Path == "/api/v1/mobile/latest-version" {
		dto.WriteSuccess(w, map[string]any{"version": info.Version, "apk_url": info.Asset("android", ""), "force_update": false, "update_description": info.Notes})
		return
	}
	dto.WriteSuccess(w, map[string]any{"version": info.Version, "current_version": buildinfo.Version, "description": info.Notes, "release_url": info.URL, "download_url": info.Asset(platform, arch), "platform": platform, "arch": arch})
}
