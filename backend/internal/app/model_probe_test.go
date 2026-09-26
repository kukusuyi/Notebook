package app

import (
	"encoding/json"
	"github.com/kukusuyi/Questrace/backend/internal/config"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestModelProbeDraftAndSecret(t *testing.T) {
	rt := newTestRuntime(t)
	token := setupAndLogin(t, rt)
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer saved-secret" {
			t.Error("saved secret not resolved")
		}
		w.Write([]byte(`{"data":[{"id":"z"},{"id":"a"},{"id":"a"}]}`))
	}))
	defer upstream.Close()
	rt.cfg.Models = []config.AIModelConfig{{Name: "saved", ProviderType: "openai_compatible", BaseURL: upstream.URL, Model: "old", APIKey: "saved-secret"}}
	req := map[string]any{"kind": "analysis", "saved_name": "saved", "config": map[string]string{"name": "renamed", "base_url": upstream.URL, "provider_type": "openai_compatible", "model": "", "api_key": "__KEEP__"}}
	code, _ := request(t, rt, "POST", "/api/v1/admin/settings/models", "", req)
	if code != 401 {
		t.Fatal(code)
	}
	code, response := request(t, rt, "POST", "/api/v1/admin/settings/models", token, req)
	if code != 200 {
		t.Fatal(code, response)
	}
	raw, _ := json.Marshal(response)
	if strings.Contains(string(raw), "secret") {
		t.Fatal("secret exposed")
	}
	list := response["data"].(map[string]any)["models"].([]any)
	if len(list) != 2 || list[0] != "a" {
		t.Fatal(list)
	}
	if rt.Config().Models[0].Model != "old" {
		t.Fatal("probe saved draft")
	}
	req["saved_name"] = "missing"
	code, _ = request(t, rt, "POST", "/api/v1/admin/settings/models", token, req)
	if code != 400 {
		t.Fatal(code)
	}
}
