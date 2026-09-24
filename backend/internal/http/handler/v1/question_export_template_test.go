package v1

import (
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/kukusuyi/Questrace/backend/internal/domain/dto"
)

func TestPrintPairsAndOmitsAnswers(t *testing.T) {
	for _, mode := range []string{exportModeQuestionsOnly, exportModeWithAnswers} {
		w := httptest.NewRecorder()
		err := renderQuestionExportHTML(w, []dto.QuestionExportItem{{QuestionCore: "<script>unsafe</script> $x^2$", StandardSolution: "SECRET_ANSWER", WrongSolution: "SECRET_WRONG"}, {QuestionCore: "second"}, {QuestionCore: "third"}}, mode)
		if err != nil {
			t.Fatal(err)
		}
		s := w.Body.String()
		if strings.Count(s, `class="sheet"`) != 2 || strings.Count(s, `class="question"`) != 3 {
			t.Fatal("must group three questions into two sheets")
		}
		if strings.Contains(s, "SECRET_") || strings.Contains(s, "<script>unsafe</script>") || strings.Contains(s, "cdn.jsdelivr") {
			t.Fatal("answers, unsafe HTML or remote resources in print")
		}
		if !strings.Contains(s, "@page { size:A4 portrait;") || !strings.Contains(s, "grid-template-rows:136mm 136mm") {
			t.Fatal("missing fixed A4 halves")
		}
	}
}
