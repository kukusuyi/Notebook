package service

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestReleaseCacheAndAssets(t *testing.T) {
	calls := 0
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		w.Write([]byte(`{"tag_name":"v2.1.0","html_url":"https://github.com/kukusuyi/Questrace/releases/tag/v2.1.0","assets":[{"name":"Questrace-2.1.0-macos-arm64.zip","browser_download_url":"https://github.com/kukusuyi/Questrace/releases/download/v2.1.0/Questrace-2.1.0-macos-arm64.zip"},{"name":"Questrace-2.1.0-android.apk","browser_download_url":"https://github.com/kukusuyi/Questrace/releases/download/v2.1.0/Questrace-2.1.0-android.apk"}]}`))
	}))
	defer srv.Close()
	svc := ReleaseService{Client: srv.Client(), Endpoint: srv.URL}
	info, err := svc.Latest()
	if err != nil {
		t.Fatal(err)
	}
	svc.Latest()
	if calls != 1 {
		t.Fatal("cache missed")
	}
	if info.Version != "2.1.0" || info.Asset("darwin", "arm64") == "" || info.Asset("android", "") == "" || info.Asset("ios", "") != "" || info.Asset("windows", "x64") != "" {
		t.Fatal(info)
	}
	svc.at = time.Now().Add(-2 * time.Hour)
	svc.Latest()
	if calls != 2 {
		t.Fatal("stale cache")
	}
}
func TestReleaseFailure(t *testing.T) {
	for _, body := range []string{`{"tag_name":"v3.0.0","draft":true}`, `{"tag_name":"v3.0.0","prerelease":true}`, `oops`} {
		srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.Write([]byte(body)) }))
		svc := ReleaseService{Client: srv.Client(), Endpoint: srv.URL}
		if _, err := svc.Latest(); err == nil {
			t.Fatal("invalid release accepted")
		}
		srv.Close()
	}
}
