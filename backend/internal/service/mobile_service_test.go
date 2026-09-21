package service

import (
	"mathnotebook/backend/internal/config"
	"testing"
)

func TestOptionalAPKUpdate(t *testing.T) {
	for _, url := range []string{"", "https://downloads.example.test/notebook.apk"} {
		svc := NewMobileService(config.MobileVersionConfig{Version: "2.0.0", DownloadURL: url}, config.FileConfig{})
		got := svc.GetLatestVersion()
		if got.APKUrl != url || got.Version != "2.0.0" {
			t.Fatalf("unexpected version response: %v", got)
		}
	}
}
