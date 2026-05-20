package enum

type VectorType string

const (
	VectorTypeSemantic VectorType = "semantic"
	VectorTypeMistake  VectorType = "mistake"
)

func IsValidVectorType(value string) bool {
	switch VectorType(value) {
	case VectorTypeSemantic, VectorTypeMistake:
		return true
	default:
		return false
	}
}
