package timeutil

import "time"

const Layout = time.RFC3339

func Format(t time.Time) string {
	return t.Format(Layout)
}
