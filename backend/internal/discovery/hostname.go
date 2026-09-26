package discovery

import (
	"net"
	"strings"

	"github.com/miekg/dns"
	"golang.org/x/net/ipv4"
)

// zeroconf publishes DNS-SD records but does not answer standalone host queries.
// This companion responder makes the advertised .local URL directly resolvable.
type hostnameResponder struct {
	conn      *ipv4.PacketConn
	done      chan struct{}
	hostname  string
	addresses map[int][]net.IP
}

func hostnameAnswer(query *dns.Msg, hostname string, ips []net.IP) *dns.Msg {
	if query.Response {
		return nil
	}
	matched := false
	for _, q := range query.Question {
		if strings.EqualFold(q.Name, dns.Fqdn(hostname)) && (q.Qclass&0x7fff) == dns.ClassINET && (q.Qtype == dns.TypeA || q.Qtype == dns.TypeANY) {
			matched = true
		}
	}
	if !matched {
		return nil
	}
	reply := new(dns.Msg)
	reply.Response = true
	reply.Authoritative = true
	for _, ip := range ips {
		if ip.To4() != nil {
			reply.Answer = append(reply.Answer, &dns.A{Hdr: dns.RR_Header{Name: dns.Fqdn(hostname), Rrtype: dns.TypeA, Class: dns.ClassINET | 0x8000, Ttl: 120}, A: ip.To4()})
		}
	}
	return reply
}

func startHostnameResponder(hostname string, ifaces []net.Interface) (*hostnameResponder, error) {
	udp, err := net.ListenUDP("udp4", &net.UDPAddr{IP: net.IPv4(224, 0, 0, 0), Port: 5353})
	if err != nil {
		return nil, err
	}
	conn := ipv4.NewPacketConn(udp)
	fail := func(err error) (*hostnameResponder, error) { conn.Close(); return nil, err }
	if err := conn.SetControlMessage(ipv4.FlagInterface, true); err != nil {
		return fail(err)
	}
	if err := conn.SetMulticastTTL(255); err != nil {
		return fail(err)
	}
	group := &net.UDPAddr{IP: net.IPv4(224, 0, 0, 251), Port: 5353}
	addresses := map[int][]net.IP{}
	for _, nic := range ifaces {
		if err := conn.JoinGroup(&nic, group); err != nil {
			return fail(err)
		}
		addrs, _ := nic.Addrs()
		for _, addr := range addrs {
			ip, _, err := net.ParseCIDR(addr.String())
			if err == nil && ip.To4() != nil && ip.IsPrivate() {
				addresses[nic.Index] = append(addresses[nic.Index], ip)
			}
		}
	}
	responder := &hostnameResponder{conn: conn, done: make(chan struct{}), hostname: hostname, addresses: addresses}
	go func() {
		defer close(responder.done)
		buffer := make([]byte, 9000)
		for {
			n, control, source, err := conn.ReadFrom(buffer)
			if err != nil {
				return
			}
			if control == nil {
				continue
			}
			query := new(dns.Msg)
			if query.Unpack(buffer[:n]) != nil {
				continue
			}
			reply := hostnameAnswer(query, hostname, addresses[control.IfIndex])
			if reply == nil || len(reply.Answer) == 0 {
				continue
			}
			destination := net.Addr(group)
			if remote, ok := source.(*net.UDPAddr); ok && remote.Port != 5353 {
				destination = source
				reply.Id = query.Id
				reply.Question = query.Question
				for _, rr := range reply.Answer {
					rr.Header().Class = dns.ClassINET
					rr.Header().Ttl = 10
				}
			}
			packet, err := reply.Pack()
			if err == nil {
				_, _ = conn.WriteTo(packet, &ipv4.ControlMessage{IfIndex: control.IfIndex}, destination)
			}
		}
	}()
	return responder, nil
}
func (r *hostnameResponder) Close() {
	query := new(dns.Msg)
	query.SetQuestion(dns.Fqdn(r.hostname), dns.TypeA)
	for index, ips := range r.addresses {
		reply := hostnameAnswer(query, r.hostname, ips)
		for _, record := range reply.Answer {
			record.Header().Ttl = 0
		}
		packet, err := reply.Pack()
		if err == nil {
			_, _ = r.conn.WriteTo(packet, &ipv4.ControlMessage{IfIndex: index}, &net.UDPAddr{IP: net.IPv4(224, 0, 0, 251), Port: 5353})
		}
	}
	r.conn.Close()
	<-r.done
}
