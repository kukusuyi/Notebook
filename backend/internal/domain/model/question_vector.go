package model

import "time"

type QuestionVector struct {
	QuestionID     int64
	VectorType     string
	CollectionName string
	VectorID       string
	EmbeddingModel string
	ContentHash    string
	Status         string
	CreatedAt      time.Time
	UpdatedAt      time.Time
}
