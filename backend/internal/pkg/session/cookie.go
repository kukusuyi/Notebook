// Package session centralises the session cookie so that the Questrace rename
// keeps existing browser sessions working: current releases write the Questrace
// cookie, still read the legacy Notebook cookie, and clear both on logout.
package session

import "net/http"

const (
	// CookieName is the session cookie written by current releases.
	CookieName = "questrace_session"
	// LegacyCookieName is the pre-rename cookie. It stays accepted so an
	// upgraded browser keeps its session, and is cleared on logout.
	LegacyCookieName = "notebook_session"
)

// Set writes the current session cookie holding token.
func Set(w http.ResponseWriter, r *http.Request, token string) {
	http.SetCookie(w, &http.Cookie{Name: CookieName, Value: token, Path: "/", HttpOnly: true, SameSite: http.SameSiteStrictMode, Secure: r.TLS != nil})
}

// Read returns the session token, falling back to the legacy cookie name.
func Read(r *http.Request) string {
	for _, name := range []string{CookieName, LegacyCookieName} {
		if c, err := r.Cookie(name); err == nil && c.Value != "" {
			return c.Value
		}
	}
	return ""
}

// Clear expires the current and the legacy session cookie.
func Clear(w http.ResponseWriter) {
	for _, name := range []string{CookieName, LegacyCookieName} {
		http.SetCookie(w, &http.Cookie{Name: name, Value: "", Path: "/", HttpOnly: true, SameSite: http.SameSiteStrictMode, MaxAge: -1})
	}
}
