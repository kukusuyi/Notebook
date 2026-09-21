package app

import (
	"net"
	"sort"
	"strconv"
)

// Addresses advertises only interfaces reachable through the bound host.
// Called on each status request so Wi-Fi address changes do not require restart.
func Addresses(host string, port int) []string {
	address := func(h string) string { return "http://" + net.JoinHostPort(h, strconv.Itoa(port)) }
	if host != "" && host != "0.0.0.0" && host != "::" {
		return []string{address(host)}
	}
	result := []string{address("127.0.0.1")}
	seen := map[string]bool{}
	interfaces, _ := net.Interfaces()
	for _, nic := range interfaces {
		if nic.Flags&net.FlagUp == 0 || nic.Flags&net.FlagLoopback != 0 {
			continue
		}
		addrs, _ := nic.Addrs()
		for _, a := range addrs {
			ip, _, err := net.ParseCIDR(a.String())
			if err == nil && ip.To4() != nil && ip.IsPrivate() {
				url := address(ip.String())
				if !seen[url] {
					seen[url] = true
					result = append(result, url)
				}
			}
		}
	}
	sort.Strings(result[1:])
	return result
}
