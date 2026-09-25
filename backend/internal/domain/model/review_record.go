package model

import "time"

type ReviewRecord struct {
	QuestionID    int64     `json:"question_id"`
	Result        string    `json:"result"`
	MasteryStatus string    `json:"mastery_status"`
	Note          string    `json:"note"`
	ReviewedAt    time.Time `json:"reviewed_at"`
	DueAt         int64     `json:"due_at"`
}
