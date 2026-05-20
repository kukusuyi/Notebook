package service

import (
	"testing"

	"mathnotebook/backend/internal/config"
)

func TestBuildAPKURLForMinIO(t *testing.T) {
	svc := NewMobileService(config.MobileVersionConfig{
		APKFilename: "math-notebook.apk",
	}, config.FileConfig{
		StorageProvider: "oss",
		DefaultBucket:   "wrong-question-images",
		MinIO: config.MinIOConfig{
			PublicBaseURL: "https://files.example.com",
		},
	})

	got := svc.buildAPKURL()
	want := "https://files.example.com/wrong-question-images/apk/math-notebook.apk"
	if got != want {
		t.Fatalf("buildAPKURL() = %q, want %q", got, want)
	}
}

func TestBuildAPKURLForLightCOS(t *testing.T) {
	svc := NewMobileService(config.MobileVersionConfig{
		APKFilename: "math-notebook.apk",
	}, config.FileConfig{
		StorageProvider: "lightcos",
		DefaultBucket:   "examplebucket-1250000000",
		LightCOS: config.LightCOSConfig{
			PublicBaseURL: "https://files.example.com",
		},
	})

	got := svc.buildAPKURL()
	want := "https://files.example.com/apk/math-notebook.apk"
	if got != want {
		t.Fatalf("buildAPKURL() = %q, want %q", got, want)
	}
}
