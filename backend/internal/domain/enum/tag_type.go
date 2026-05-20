package enum

type TagType string

const (
	TagTypeKnowledgePoint TagType = "knowledge_point"
	TagTypeProblemType    TagType = "problem_type"
	TagTypeMethod         TagType = "method"
	TagTypeMistakeReason  TagType = "mistake_reason"
)

func IsValidTagType(value string) bool {
	switch TagType(value) {
	case TagTypeKnowledgePoint, TagTypeProblemType, TagTypeMethod, TagTypeMistakeReason:
		return true
	default:
		return false
	}
}
