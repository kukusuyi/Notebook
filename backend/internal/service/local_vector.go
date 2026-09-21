package service

import (
	"context"
	"database/sql"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"math"
	"sort"
	"strings"
	"time"

	"mathnotebook/backend/internal/config"
	"mathnotebook/backend/internal/domain/model"
	ai "mathnotebook/backend/internal/infra/ai"
	apperrors "mathnotebook/backend/internal/pkg/errors"
	"mathnotebook/backend/internal/repository"
)

type LocalVector struct {
	DB     *sql.DB
	Config func() config.EmbeddingModelConfig
}

func (s *LocalVector) modelKey(c config.EmbeddingModelConfig) string {
	return c.ProviderType + "|" + strings.TrimRight(c.BaseURL, "/") + "|" + c.Model
}
func vectorBytes(v []float64) []byte {
	b := make([]byte, len(v)*4)
	for i, x := range v {
		binary.LittleEndian.PutUint32(b[i*4:], math.Float32bits(float32(x)))
	}
	return b
}
func cosine(v []float64, b []byte) float64 {
	if len(b) != len(v)*4 {
		return -2
	}
	var dot, a, c float64
	for i, x := range v {
		y := float64(math.Float32frombits(binary.LittleEndian.Uint32(b[i*4:])))
		dot += x * y
		a += x * x
		c += y * y
	}
	if a == 0 || c == 0 {
		return -2
	}
	return dot / math.Sqrt(a*c)
}
func (s *LocalVector) Run(ctx context.Context) {
	tick := time.NewTicker(time.Second)
	defer tick.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-tick.C:
			s.step(ctx)
		}
	}
}
func (s *LocalVector) step(ctx context.Context) {
	cfg := s.Config()
	if cfg.APIKey == "" {
		return
	}
	var id, revision int64
	err := s.DB.QueryRowContext(ctx, "SELECT question_id,revision FROM vector_job WHERE status <> 'done' AND next_attempt<=? ORDER BY next_attempt,question_id LIMIT 1", time.Now().Unix()).Scan(&id, &revision)
	if err != nil {
		return
	}
	client, err := ai.NewEmbeddingClient(cfg)
	if err != nil {
		return
	}
	q, ok := repository.NewSQLiteQuestionRepository(s.DB).GetByID(id)
	if !ok {
		return
	}
	type item struct {
		kind, hash string
		vector     []float64
	}
	var items []item
	if !q.IsDeleted {
		for _, kind := range []string{"semantic", "mistake"} {
			text := buildSearchText(q, kind)
			if text == "" {
				continue
			}
			var v []float64
			v, err = client.Embed(ctx, text)
			if err != nil {
				break
			}
			if len(v) == 0 {
				err = fmt.Errorf("empty embedding")
				break
			}
			items = append(items, item{kind, hashText(text), v})
		}
	}
	if err != nil {
		_, _ = s.DB.ExecContext(ctx, "UPDATE vector_job SET status='failed',attempts=attempts+1,next_attempt=?,error='模型请求失败，可检查设置后重试' WHERE question_id=? AND revision=?", time.Now().Add(time.Minute).Unix(), id, revision)
		return
	}
	if s.modelKey(s.Config()) != s.modelKey(cfg) {
		return
	}
	tx, err := s.DB.BeginTx(ctx, nil)
	if err != nil {
		return
	}
	defer tx.Rollback()
	var current int64
	if err = tx.QueryRow("SELECT revision FROM vector_job WHERE question_id=?", id).Scan(&current); err != nil || current != revision {
		return
	}
	if _, err = tx.Exec("DELETE FROM local_vector WHERE question_id=?", id); err != nil {
		return
	}
	for _, item := range items {
		if _, err = tx.Exec("INSERT INTO local_vector(question_id,vector_type,model,dimension,content_hash,vector) VALUES(?,?,?,?,?,?)", id, item.kind, s.modelKey(cfg), len(item.vector), item.hash, vectorBytes(item.vector)); err != nil {
			return
		}
	}
	if _, err = tx.Exec("UPDATE vector_job SET status='done',error='' WHERE question_id=? AND revision=?", id, revision); err != nil {
		return
	}
	_ = tx.Commit()
}
func (s *LocalVector) Search(base model.WrongQuestion, kind string, limit int, filter bool) ([]SimilarSearchItem, error) {
	cfg := s.Config()
	if cfg.APIKey == "" {
		return nil, apperrors.New(503, 50301, "请管理员先配置 Embedding 模型")
	}
	client, err := ai.NewEmbeddingClient(cfg)
	if err != nil {
		return nil, err
	}
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()
	v, err := client.Embed(ctx, buildSearchText(base, kind))
	if err != nil {
		return nil, apperrors.New(503, 50302, "向量模型暂不可用")
	}
	query := `SELECT v.question_id,v.vector FROM local_vector v JOIN wrong_question q ON q.id=v.question_id WHERE q.user_id=? AND q.is_deleted=0 AND v.vector_type=? AND v.model=? AND v.dimension=? AND q.id<>?`
	args := []any{base.UserID, kind, s.modelKey(cfg), len(v), base.ID}
	if base.Subject != "" {
		query += " AND q.subject=?"
		args = append(args, base.Subject)
	}
	if filter {
		groups := []struct {
			kind   string
			values []string
		}{{"knowledge_point", base.Tags.KnowledgePoints}, {"problem_type", base.Tags.ProblemType}, {"method", base.Tags.Method}}
		if kind == "mistake" {
			groups = append(groups, struct {
				kind   string
				values []string
			}{"mistake_reason", base.Tags.MistakeReason})
		}
		for _, g := range groups {
			if len(g.values) == 0 {
				continue
			}
			b, _ := json.Marshal(g.values)
			query += ` AND EXISTS(SELECT 1 FROM wrong_question_tag qt JOIN tag t ON t.id=qt.tag_id WHERE qt.question_id=q.id AND t.is_active=1 AND t.tag_type=? AND t.tag_name IN (SELECT value FROM json_each(?)))`
			args = append(args, g.kind, string(b))
		}
	}
	rows, err := s.DB.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	if limit <= 0 {
		limit = 10
	}
	if limit > 100 {
		limit = 100
	}
	items := make([]SimilarSearchItem, 0, limit+1)
	for rows.Next() {
		var id int64
		var b []byte
		if err = rows.Scan(&id, &b); err != nil {
			return nil, err
		}
		score := cosine(v, b)
		if math.IsNaN(score) || math.IsInf(score, 0) || score < -1 {
			continue
		}
		items = append(items, SimilarSearchItem{QuestionID: id, Score: score})
		sort.Slice(items, func(i, j int) bool {
			if items[i].Score == items[j].Score {
				return items[i].QuestionID < items[j].QuestionID
			}
			return items[i].Score > items[j].Score
		})
		if len(items) > limit {
			items = items[:limit]
		}
	}
	return items, rows.Err()
}
