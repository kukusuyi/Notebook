package enum

type SourceType string

const (
	SourceTypeManual SourceType = "manual"
	SourceTypeImage  SourceType = "image"
	SourceTypeImport SourceType = "import"
)

func IsValidSourceType(value string) bool {
	switch SourceType(value) {
	case SourceTypeManual, SourceTypeImage, SourceTypeImport:
		return true
	default:
		return false
	}
}
