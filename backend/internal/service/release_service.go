package service

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"sync"
	"time"
)

type ReleaseAsset struct {
	Name string `json:"name"`
	URL  string `json:"browser_download_url"`
}
type ReleaseInfo struct {
	Version    string         `json:"tag_name"`
	Notes      string         `json:"body"`
	URL        string         `json:"html_url"`
	Draft      bool           `json:"draft"`
	Prerelease bool           `json:"prerelease"`
	Assets     []ReleaseAsset `json:"assets"`
}
type ReleaseService struct {
	mu       sync.Mutex
	cached   ReleaseInfo
	at       time.Time
	Client   *http.Client
	Endpoint string
}

var Releases = &ReleaseService{Client: &http.Client{Timeout: 10 * time.Second}, Endpoint: "https://api.github.com/repos/kukusuyi/Questrace/releases/latest"}

func (s *ReleaseService) Latest() (ReleaseInfo, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if !s.at.IsZero() && time.Since(s.at) < time.Hour {
		return s.cached, nil
	}
	req, err := http.NewRequest("GET", s.Endpoint, nil)
	if err != nil {
		return ReleaseInfo{}, err
	}
	req.Header.Set("Accept", "application/vnd.github+json")
	req.Header.Set("User-Agent", "Questrace-version-check")
	res, err := s.Client.Do(req)
	if err != nil {
		return ReleaseInfo{}, fmt.Errorf("无法连接 GitHub，请稍后重试")
	}
	defer res.Body.Close()
	if res.StatusCode != 200 {
		return ReleaseInfo{}, fmt.Errorf("GitHub 版本查询失败（%d）", res.StatusCode)
	}
	var info ReleaseInfo
	if err = json.NewDecoder(res.Body).Decode(&info); err != nil {
		return info, err
	}
	if info.Draft || info.Prerelease || info.Version == "" {
		return info, fmt.Errorf("尚无可用的正式版本")
	}
	info.Version = strings.TrimPrefix(info.Version, "v")
	s.cached = info
	s.at = time.Now()
	return info, nil
}
func (info ReleaseInfo) Asset(platform, arch string) string {
	if platform == "darwin" {
		platform = "macos"
	}
	if platform == "win32" {
		platform = "windows"
	}
	if arch == "amd64" && platform != "linux" {
		arch = "x64"
	}
	if arch == "x64" && platform == "linux" {
		arch = "amd64"
	}
	suffix := ""
	switch platform {
	case "android":
		suffix = "android.apk"
	case "windows":
		suffix = "windows-" + arch + "-Setup.exe"
	case "macos":
		suffix = "macos-" + arch + ".zip"
	case "linux":
		suffix = "linux-" + arch + ".tar.gz"
	default:
		return ""
	}
	for _, a := range info.Assets {
		if a.Name == "Questrace-"+info.Version+"-"+suffix && strings.HasPrefix(a.URL, "https://github.com/kukusuyi/Questrace/releases/download/") {
			return a.URL
		}
	}
	return ""
}
