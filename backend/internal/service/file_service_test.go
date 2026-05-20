package service

import (
	"testing"

	"mathnotebook/backend/internal/config"
)

func TestResolvePublicFileURLAutoRewriteForDevelopment(t *testing.T) {
	svc := NewFileService(nil, nil, config.FileConfig{
		BaseURL: "http://127.0.0.1:9000",
		MinIO: config.MinIOConfig{
			PublicBaseURL: "http://127.0.0.1:9000",
		},
	}, "local")

	got := svc.resolvePublicFileURL(
		"http://127.0.0.1:9000/wrong-question-images/wrong-question/test.png",
		"http",
		"192.0.2.18:8080",
	)

	want := "http://192.0.2.18:9000/wrong-question-images/wrong-question/test.png"
	if got != want {
		t.Fatalf("resolvePublicFileURL() = %q, want %q", got, want)
	}
}

func TestResolvePublicFileURLKeepsConfiguredNonLoopbackURL(t *testing.T) {
	svc := NewFileService(nil, nil, config.FileConfig{
		BaseURL: "http://192.0.2.18:9000",
		MinIO: config.MinIOConfig{
			PublicBaseURL: "http://192.0.2.18:9000",
		},
	}, "local")

	got := svc.resolvePublicFileURL(
		"http://192.0.2.18:9000/wrong-question-images/wrong-question/test.png",
		"http",
		"192.0.2.19:8080",
	)

	want := "http://192.0.2.18:9000/wrong-question-images/wrong-question/test.png"
	if got != want {
		t.Fatalf("resolvePublicFileURL() = %q, want %q", got, want)
	}
}

func TestResolvePublicFileURLSkipsRewriteOutsideDevelopment(t *testing.T) {
	svc := NewFileService(nil, nil, config.FileConfig{
		BaseURL: "http://127.0.0.1:9000",
		MinIO: config.MinIOConfig{
			PublicBaseURL: "http://127.0.0.1:9000",
		},
	}, "production")

	got := svc.resolvePublicFileURL(
		"http://127.0.0.1:9000/wrong-question-images/wrong-question/test.png",
		"http",
		"192.0.2.18:8080",
	)

	want := "http://127.0.0.1:9000/wrong-question-images/wrong-question/test.png"
	if got != want {
		t.Fatalf("resolvePublicFileURL() = %q, want %q", got, want)
	}
}
