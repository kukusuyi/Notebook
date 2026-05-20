package ocr

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestShouldInlineImageURL(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name string
		raw  string
		want bool
	}{
		{name: "localhost", raw: "http://localhost:9001/image.png", want: true},
		{name: "loopback ipv4", raw: "http://127.0.0.1:9001/image.png", want: true},
		{name: "private ipv4", raw: "http://192.168.1.10:9001/image.png", want: true},
		{name: "public https", raw: "https://example.com/image.png", want: false},
		{name: "data url", raw: "data:image/png;base64,abcd", want: false},
	}

	for _, tc := range tests {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			if got := shouldInlineImageURL(tc.raw); got != tc.want {
				t.Fatalf("shouldInlineImageURL(%q) = %v, want %v", tc.raw, got, tc.want)
			}
		})
	}
}

func TestDownloadAsDataURL(t *testing.T) {
	t.Parallel()

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "image/png")
		_, _ = w.Write([]byte{0x89, 'P', 'N', 'G', '\r', '\n', 0x1a, '\n'})
	}))
	defer server.Close()

	client := NewQwenOCRClient("test-key", "test-model")
	client.downloadClient = server.Client()

	dataURL, err := client.downloadAsDataURL(context.Background(), server.URL+"/question.png")
	if err != nil {
		t.Fatalf("downloadAsDataURL: %v", err)
	}

	if !strings.HasPrefix(dataURL, "data:image/png;base64,") {
		t.Fatalf("unexpected data url prefix: %s", dataURL)
	}
}
