package errors

import (
	"strings"
	"testing"
)

func TestProviderMessage(t *testing.T) {
	for _, c := range []struct {
		status    int
		raw, want string
	}{{401, "secret", "API Key"}, {403, "secret", "权限"}, {429, "secret", "限流"}, {402, "secret", "额度"}, {500, "insufficient quota sk-secret", "额度"}, {0, "dial tcp connection refused sk-secret", "无法连接"}, {0, "context deadline exceeded", "超时"}, {400, "InvalidParameter", "不受支持"}, {500, "decode response sk-secret", "格式异常"}, {500, "unrecognized sk-secret", "暂时"}} {
		got := ProviderMessage(c.status, c.raw)
		if !strings.Contains(got, c.want) || strings.Contains(got, "secret") {
			t.Errorf("got %q want %q", got, c.want)
		}
	}
}
