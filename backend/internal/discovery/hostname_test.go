package discovery

import (
	"github.com/miekg/dns"
	"net"
	"testing"
)

func TestHostnameAnswer(t *testing.T) {
	for _, tc := range []struct {
		name     string
		kind     uint16
		response bool
		want     bool
	}{
		{"questrace-mac-abc.local.", dns.TypeA, false, true},
		{"QUESTRACE-MAC-ABC.local.", dns.TypeANY, false, true},
		{"other.local.", dns.TypeA, false, false},
		{"questrace-mac-abc.local.", dns.TypeAAAA, false, false},
		{"questrace-mac-abc.local.", dns.TypeA, true, false},
	} {
		q := new(dns.Msg)
		q.SetQuestion(tc.name, tc.kind)
		q.Response = tc.response
		result := hostnameAnswer(q, "questrace-mac-abc.local", []net.IP{net.ParseIP("192.168.1.27")})
		if (result != nil) != tc.want {
			t.Fatalf("%+v: %v", tc, result)
		}
		if result != nil {
			packet, err := result.Pack()
			if err != nil {
				t.Fatal(err)
			}
			decoded := new(dns.Msg)
			if err := decoded.Unpack(packet); err != nil {
				t.Fatal(err)
			}
			a := decoded.Answer[0].(*dns.A)
			if a.A.String() != "192.168.1.27" || a.Hdr.Class != dns.ClassINET|0x8000 {
				t.Fatal(a)
			}
		}
	}
}
