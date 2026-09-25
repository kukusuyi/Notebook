package repository

import (
	"github.com/kukusuyi/Questrace/backend/internal/infra/sqlite"
	"testing"
)

func TestNormalizedSearchAndExactTags(t *testing.T) {
	db, err := sqlite.Open(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	_, err = db.Exec(`INSERT INTO user(id,username)VALUES(1,'one'),(2,'two');
 INSERT INTO wrong_question(id,user_id,subject,question_core,semantic_summary)VALUES(1,1,'math','\cos{x}',''),(2,1,'math','cos x',''),(3,2,'math','cosx','');
 INSERT INTO tag(id,user_id,tag_type,tag_name)VALUES(1,1,'method','same'),(2,1,'knowledge_point','same');
 INSERT INTO wrong_question_tag(question_id,tag_id,tag_type)VALUES(1,1,'method'),(2,2,'knowledge_point');`)
	if err != nil {
		t.Fatal(err)
	}
	repo := NewSQLiteQuestionRepository(db)
	for _, q := range []string{"cosx", "COS X", `\cos{x}`} {
		_, n, err := repo.List(QuestionFilter{UserID: 1, Keyword: q, Page: 1, PageSize: 10})
		if err != nil || n != 2 {
			t.Fatal(q, n, err)
		}
	}
	for _, id := range []int64{1, 2, 999} {
		items, n, err := repo.List(QuestionFilter{UserID: 1, TagIDs: []int64{id}, Page: 1, PageSize: 10})
		if err != nil {
			t.Fatal(err)
		}
		if id == 999 {
			if n != 0 {
				t.Fatal("missing tag returned all")
			}
		} else if n != 1 || items[0].ID != id {
			t.Fatal("tag type conflated", items)
		}
	}
	db.Exec(`UPDATE tag SET tag_name='Trigonometry' WHERE id=1`)
	_, n, err := repo.List(QuestionFilter{UserID: 1, Keyword: "trigono metry", Page: 1, PageSize: 10})
	if err != nil || n != 1 {
		t.Fatal("tag search", n, err)
	}
	db.Exec(`UPDATE tag SET is_active=0 WHERE id=1`)
	_, n, err = repo.List(QuestionFilter{UserID: 1, Keyword: "trigonometry", Page: 1, PageSize: 10})
	if err != nil || n != 0 {
		t.Fatal("deleted tag search", n, err)
	}
}
