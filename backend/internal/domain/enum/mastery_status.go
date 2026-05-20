package enum

type MasteryStatus string

const (
	MasteryStatusUnmastered MasteryStatus = "unmastered"
	MasteryStatusLearning   MasteryStatus = "learning"
	MasteryStatusMastered   MasteryStatus = "mastered"
)

func IsValidMasteryStatus(value string) bool {
	switch MasteryStatus(value) {
	case MasteryStatusUnmastered, MasteryStatusLearning, MasteryStatusMastered:
		return true
	default:
		return false
	}
}
