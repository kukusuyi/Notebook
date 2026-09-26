package discovery

import (
	"context"
	"runtime"
	"testing"
	"time"
)

func TestStableDomainAndDisabledLinux(t *testing.T) {
	a := New("aabbccddeeff", "127.0.0.1", 8080)
	b := New("aabbccddeeff", "0.0.0.0", 9090)
	if a.Status().Hostname != b.Status().Hostname {
		t.Fatal("port changed identity")
	}
	if runtime.GOOS == "linux" {
		if a.Status().State != "disabled" {
			t.Fatal("Linux enabled")
		}
		return
	}
	if a.Status().Hostname == New("112233445566", "0.0.0.0", 8080).Status().Hostname {
		t.Fatal("device collision")
	}
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() { a.Run(ctx); close(done) }()
	cancel()
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("shutdown stalled")
	}
	if a.URL() != "" {
		t.Fatal("advertised stopped service")
	}
}
