package service

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestRegionAndFallback(t *testing.T) {
	for _, tc := range []struct {
		name, country string
		gitcodeStatus int
		gitcodeBody   string
		want          string
	}{
		{"mainland", "CN", 200, "", "gitcode"}, {"overseas", "US", 200, "", "github"}, {"unknown", "oops", 200, "", "gitcode"}, {"outage", "CN", 503, "", "github"}, {"pre", "CN", 200, `{"tag_name":"v2.1.1","release_status":"pre"}`, "github"}, {"missing asset", "CN", 200, `{"tag_name":"v2.1.1"}`, "github"}, {"downgrade", "CN", 200, `{"tag_name":"v2.0.0"}`, "github"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			calls := []string{}
			srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				if r.URL.Path == "/country" {
					fmt.Fprint(w, tc.country)
					return
				}
				calls = append(calls, r.URL.Path)
				if r.URL.Path == "/gc" {
					w.WriteHeader(tc.gitcodeStatus)
					if tc.gitcodeBody != "" {
						fmt.Fprint(w, tc.gitcodeBody)
						return
					}
				}
				fmt.Fprint(w, `{"tag_name":"v2.1.1","assets":[{"name":"Questrace-2.1.1-android.apk","browser_download_url":"https://github.com/kukusuyi/Questrace/releases/download/v2.1.1/Questrace-2.1.1-android.apk"}]}`)
			}))
			defer srv.Close()
			svc := ReleaseService{Client: srv.Client(), Endpoint: srv.URL + "/gh", GitCodeEndpoint: srv.URL + "/gc", CountryEndpoint: srv.URL + "/country"}
			info, err := svc.LatestFor(context.Background(), "android", "", "2.1.0")
			if err != nil || info.Source != tc.want || info.Asset("android", "") == "" {
				t.Fatal(info, err, calls)
			}
			count := len(calls)
			svc.LatestFor(context.Background(), "android", "", "2.1.0")
			if tc.gitcodeStatus == 200 && tc.gitcodeBody == "" && len(calls) != count {
				t.Fatal("cache missed")
			}
		})
	}
}
func TestVersionAndDownloadBoundaries(t *testing.T) {
	if !versionLess("2.9.0", "2.10.0") || versionLess("2.1.1", "2.1.0") {
		t.Fatal("version order")
	}
	for _, raw := range []string{"https://github.com.evil/kukusuyi/Questrace/releases/download/a", "https://evil@github.com/kukusuyi/Questrace/releases/download/a", "http://api.gitcode.com/api/v5/repos/xiaosusu/Questrace/releases/v2.1.1/attach_files/a/download"} {
		if trustedReleaseAsset(raw) {
			t.Fatal(raw)
		}
	}
}
