// Package discovery publishes stable per-installation desktop LAN addresses.
package discovery

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"github.com/libp2p/zeroconf/v2"
	"net"
	"runtime"
	"sort"
	"strings"
	"sync"
	"time"
)

type Status struct {
	DeviceID string `json:"device_id"`
	Hostname string `json:"hostname"`
	Port     int    `json:"port"`
	State    string `json:"state"`
}
type Publisher struct {
	mu     sync.RWMutex
	status Status
	host   string
}

func New(id, host string, port int) *Publisher {
	prefix := map[string]string{"windows": "win", "darwin": "mac"}[runtime.GOOS]
	status := Status{Port: port, State: "disabled"}
	if prefix != "" {
		status.DeviceID = id
		status.Hostname = "questrace-" + prefix + "-" + id + ".local"
		status.State = "starting"
	}
	return &Publisher{status: status, host: host}
}
func (p *Publisher) Status() Status    { p.mu.RLock(); defer p.mu.RUnlock(); return p.status }
func (p *Publisher) setState(s string) { p.mu.Lock(); p.status.State = s; p.mu.Unlock() }
func (p *Publisher) URL() string {
	s := p.Status()
	if s.State != "available" {
		return ""
	}
	return fmt.Sprintf("http://%s:%d", s.Hostname, s.Port)
}
func Interfaces(host string) ([]net.Interface, []string) {
	all, _ := net.Interfaces()
	var ifaces []net.Interface
	var ips []string
	for _, nic := range all {
		if nic.Flags&net.FlagUp == 0 || nic.Flags&net.FlagLoopback != 0 || nic.Flags&net.FlagMulticast == 0 {
			continue
		}
		addresses, _ := nic.Addrs()
		valid := false
		for _, a := range addresses {
			ip, _, err := net.ParseCIDR(a.String())
			if err != nil || ip.To4() == nil || !ip.IsPrivate() {
				continue
			}
			if host != "" && host != "0.0.0.0" && host != "::" && host != ip.String() {
				continue
			}
			ips = append(ips, ip.String())
			valid = true
		}
		if valid {
			ifaces = append(ifaces, nic)
		}
	}
	sort.Strings(ips)
	return ifaces, ips
}
func NetworkKey() string {
	_, ips := Interfaces("")
	sum := sha256.Sum256([]byte(strings.Join(ips, ",")))
	return hex.EncodeToString(sum[:])
}
func (p *Publisher) Run(ctx context.Context) {
	s := p.Status()
	if s.State == "disabled" {
		return
	}
	var server *zeroconf.Server
	var hostnameServer *hostnameResponder
	var signature string
	defer func() {
		if server != nil {
			server.Shutdown()
		}
		if hostnameServer != nil {
			hostnameServer.Close()
		}
		p.setState("stopped")
	}()
	refresh := func() {
		ifaces, ips := Interfaces(p.host)
		parts := append([]string{}, ips...)
		for _, i := range ifaces {
			parts = append(parts, fmt.Sprintf("%d:%s", i.Index, i.Name))
		}
		next := strings.Join(parts, ",")
		if next == signature && server != nil {
			return
		}
		if server != nil {
			server.Shutdown()
			server = nil
		}
		if hostnameServer != nil {
			hostnameServer.Close()
			hostnameServer = nil
		}
		signature = next
		if len(ips) == 0 {
			p.setState("unavailable")
			return
		}
		var err error
		server, err = zeroconf.RegisterProxy("Questrace-"+s.DeviceID, "_questrace._tcp", "local.", s.Port, s.Hostname+".", ips, []string{"id=" + s.DeviceID, "version=1", "path=/"}, ifaces)
		if err != nil {
			p.setState("unavailable")
		} else {
			hostnameServer, err = startHostnameResponder(s.Hostname, ifaces)
			if err != nil {
				server.Shutdown()
				server = nil
				p.setState("unavailable")
				return
			}
			p.setState("available")
		}
	}
	refresh()
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			refresh()
		}
	}
}
