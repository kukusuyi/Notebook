package sqlite

import (
	"net/url"
	"testing"
)

func TestDatabaseURL(t *testing.T) {
	for _, path := range []string{"C:/Users/中文 data/notebook.db", "/tmp/中文 data/notebook.db"} {
		uri := databaseURL(path)
		parsed, err := url.Parse(uri.String())
		if err != nil || parsed.Host != "" || parsed.Path[0] != '/' {
			t.Fatalf("invalid SQLite URI: %s", uri.String())
		}
	}
}
