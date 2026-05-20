package model

import "time"

type Tag struct {
	ID         int64
	UserID     int64
	TagName    string
	TagType    string
	UsageCount int
	IsActive   bool
	DeletedAt  *time.Time
	CreatedAt  time.Time
	UpdatedAt  time.Time
}

type TagCollections struct {
	KnowledgePoints []string
	ProblemType     []string
	Method          []string
	MistakeReason   []string
}
