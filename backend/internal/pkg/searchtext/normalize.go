package searchtext

import (
	"regexp"
	"strings"
	"unicode"
)

var spacing = regexp.MustCompile(`\\(?:left|right|quad|qquad|displaystyle|textstyle)\b|\\[,;!: ]`)

// Normalize removes presentation only, retaining mathematical operators.
func Normalize(s string) string {
	s = spacing.ReplaceAllString(strings.ToLower(s), "")
	return strings.Map(func(r rune) rune {
		if unicode.IsSpace(r) || strings.ContainsRune(`\{}$`, r) {
			return -1
		}
		return r
	}, s)
}
