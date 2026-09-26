package app

import (
	"context"
	"github.com/kukusuyi/Questrace/backend/internal/config"
	"github.com/kukusuyi/Questrace/backend/internal/domain/dto"
	ai "github.com/kukusuyi/Questrace/backend/internal/infra/ai"
	apperrors "github.com/kukusuyi/Questrace/backend/internal/pkg/errors"
	"net/http"
	"time"
)

// probeModels inspects a draft configuration without saving it or exposing secrets.
func (s *LocalRuntime) probeModels(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		fail(w, 405, "不支持此操作")
		return
	}
	var req struct {
		Kind      string               `json:"kind"`
		SavedName string               `json:"saved_name"`
		Config    config.AIModelConfig `json:"config"`
	}
	if dto.DecodeJSON(r, &req) != nil {
		fail(w, 400, "模型配置格式错误")
		return
	}
	cfg := req.Config
	old := s.Config()
	if req.Kind == "ocr" {
		cfg.Name = "ocr"
		cfg.ProviderType = "qwen"
		cfg.BaseURL = ""
		if cfg.APIKey == "__KEEP__" {
			cfg.APIKey = old.ImageOcr.APIKey
		}
	} else if req.Kind == "analysis" {
		if cfg.APIKey == "__KEEP__" {
			cfg.APIKey = ""
			for _, saved := range old.Models {
				if saved.Name == req.SavedName {
					cfg.APIKey = saved.APIKey
					break
				}
			}
		}
		cfg.Name = "probe"
	} else {
		fail(w, 400, "不支持的模型类型")
		return
	}
	// Listing does not require a chosen model.
	if cfg.Model == "" {
		cfg.Model = "probe"
	}
	registry, err := ai.NewRegistry([]config.AIModelConfig{cfg})
	if err != nil {
		fail(w, 400, "请填写有效的接口地址和 API Key")
		return
	}
	client, _ := registry.Provider(cfg.Name)
	ctx, cancel := context.WithTimeout(r.Context(), 15*time.Second)
	defer cancel()
	models, err := client.ListModels(ctx)
	if err != nil {
		fail(w, 502, apperrors.ProviderMessage(0, err.Error()))
		return
	}
	list := make([]string, 0, len(models))
	seen := map[string]bool{}
	for _, m := range models {
		if !seen[m.ID] {
			list = append(list, m.ID)
			seen[m.ID] = true
		}
	}
	dto.WriteSuccess(w, map[string]any{"models": list})
}
