package service

import (
	"context"
	"encoding/json"
	"fmt"
	"github.com/kukusuyi/Questrace/backend/internal/discovery"
	"io"
	"net/http"
	"net/url"
	"regexp"
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
	Status     string         `json:"release_status"`
	Assets     []ReleaseAsset `json:"assets"`
	Source     string         `json:"-"`
}
type cachedRelease struct {
	info ReleaseInfo
	at   time.Time
}
type ReleaseService struct {
	mu              sync.Mutex
	cached          ReleaseInfo
	at              time.Time
	Client          *http.Client
	Endpoint        string
	GitCodeEndpoint string
	CountryEndpoint string
	country         string
	countryAt       time.Time
	network         string
	cache           map[string]cachedRelease
}

var Releases = &ReleaseService{Client: &http.Client{Timeout: 8 * time.Second}, Endpoint: "https://api.github.com/repos/kukusuyi/Questrace/releases/latest", GitCodeEndpoint: "https://api.gitcode.com/api/v5/repos/xiaosusu/Questrace/releases/latest?type=latest", CountryEndpoint: "https://ipapi.co/country/"}
var stableVersion = regexp.MustCompile(`^v?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$`)

func versionLess(a, b string) bool {
	if !stableVersion.MatchString(a) || !stableVersion.MatchString(b) {
		return false
	}
	aa := strings.Split(strings.TrimPrefix(a, "v"), ".")
	bb := strings.Split(strings.TrimPrefix(b, "v"), ".")
	for i := range aa {
		if len(aa[i]) != len(bb[i]) {
			return len(aa[i]) < len(bb[i])
		}
		if aa[i] != bb[i] {
			return aa[i] < bb[i]
		}
	}
	return false
}
func (s *ReleaseService) countryCode(ctx context.Context) string {
	key := discovery.NetworkKey()
	if key != s.network {
		s.network = key
		s.countryAt = time.Time{}
		s.cache = nil
	}
	if !s.countryAt.IsZero() && time.Since(s.countryAt) < 24*time.Hour {
		return s.country
	}
	if s.CountryEndpoint == "" {
		return ""
	}
	ctx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, "GET", s.CountryEndpoint, nil)
	if err != nil {
		return ""
	}
	res, err := s.Client.Do(req)
	if err != nil {
		return ""
	}
	defer res.Body.Close()
	if res.StatusCode != 200 {
		return ""
	}
	raw, err := io.ReadAll(io.LimitReader(res.Body, 16))
	code := strings.TrimSpace(string(raw))
	if err != nil || !regexp.MustCompile(`^[A-Z]{2}$`).MatchString(code) {
		return ""
	}
	s.country = code
	s.countryAt = time.Now()
	return code
}
func (s *ReleaseService) fetch(ctx context.Context, endpoint, source string) (ReleaseInfo, error) {
	if s.cache == nil {
		s.cache = map[string]cachedRelease{}
	}
	if c, ok := s.cache[endpoint]; ok && time.Since(c.at) < time.Hour {
		return c.info, nil
	}
	ctx, cancel := context.WithTimeout(ctx, 8*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, "GET", endpoint, nil)
	if err != nil {
		return ReleaseInfo{}, err
	}
	req.Header.Set("Accept", "application/json")
	req.Header.Set("User-Agent", "Questrace-version-check")
	res, err := s.Client.Do(req)
	if err != nil {
		return ReleaseInfo{}, fmt.Errorf("无法连接更新源")
	}
	defer res.Body.Close()
	if res.StatusCode != 200 {
		return ReleaseInfo{}, fmt.Errorf("版本查询失败（%d）", res.StatusCode)
	}
	var info ReleaseInfo
	if err = json.NewDecoder(io.LimitReader(res.Body, 2<<20)).Decode(&info); err != nil {
		return info, fmt.Errorf("更新源响应无效")
	}
	if info.Draft || info.Prerelease || !stableVersion.MatchString(info.Version) || (source == "gitcode" && info.Status != "" && info.Status != "latest") {
		return info, fmt.Errorf("尚无可用的正式版本")
	}
	tag := info.Version
	info.Version = strings.TrimPrefix(tag, "v")
	info.Source = source
	if source == "gitcode" {
		info.URL = "https://gitcode.com/xiaosusu/Questrace/releases/tag/" + url.PathEscape(tag)
		for i := range info.Assets {
			a := &info.Assets[i]
			if strings.ContainsAny(a.Name, "/\\") {
				a.URL = ""
				continue
			}
			a.URL = "https://api.gitcode.com/api/v5/repos/xiaosusu/Questrace/releases/" + url.PathEscape(tag) + "/attach_files/" + url.PathEscape(a.Name) + "/download"
		}
	} else {
		info.URL = "https://github.com/kukusuyi/Questrace/releases/tag/" + url.PathEscape(tag)
	}
	s.cache[endpoint] = cachedRelease{info, time.Now()}
	return info, nil
}

// Latest is retained for callers that do not request a platform asset.
func (s *ReleaseService) Latest() (ReleaseInfo, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if !s.at.IsZero() && time.Since(s.at) < time.Hour {
		return s.cached, nil
	}
	s.cache = nil
	info, err := s.fetch(context.Background(), s.Endpoint, "github")
	if err == nil {
		s.cached = info
		s.at = time.Now()
	}
	return info, err
}
func (s *ReleaseService) LatestFor(ctx context.Context, platform, arch, current string) (ReleaseInfo, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	country := s.countryCode(ctx)
	sources := []struct{ endpoint, name string }{{s.Endpoint, "github"}, {s.GitCodeEndpoint, "gitcode"}}
	if country == "CN" || country == "" {
		sources[0], sources[1] = sources[1], sources[0]
	}
	var noUpdate *ReleaseInfo
	for _, source := range sources {
		if source.endpoint == "" {
			continue
		}
		info, err := s.fetch(ctx, source.endpoint, source.name)
		if err != nil {
			continue
		}
		if versionLess(info.Version, current) {
			continue
		}
		if info.Version == strings.TrimPrefix(current, "v") {
			copy := info
			noUpdate = &copy
		}
		if platform != "ios" && info.Asset(platform, arch) == "" {
			continue
		}
		return info, nil
	}
	if noUpdate != nil {
		return *noUpdate, nil
	}
	return ReleaseInfo{}, fmt.Errorf("暂时无法获取此平台的正式版本，请稍后重试")
}
func trustedReleaseAsset(raw string) bool {
	u, err := url.Parse(raw)
	if err != nil || u.Scheme != "https" || u.User != nil || u.Port() != "" || u.RawQuery != "" || u.Fragment != "" {
		return false
	}
	if u.Hostname() == "github.com" {
		return strings.HasPrefix(u.Path, "/kukusuyi/Questrace/releases/download/")
	}
	return u.Hostname() == "api.gitcode.com" && strings.HasPrefix(u.Path, "/api/v5/repos/xiaosusu/Questrace/releases/") && strings.Contains(u.Path, "/attach_files/") && strings.HasSuffix(u.Path, "/download")
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
		if a.Name == "Questrace-"+info.Version+"-"+suffix && trustedReleaseAsset(a.URL) {
			return a.URL
		}
	}
	return ""
}
