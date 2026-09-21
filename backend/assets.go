package assets

import "embed"

//go:embed ocr_prompt.md prompts/chapters/*.md prompts/chapter_router.md all:web
var Files embed.FS
