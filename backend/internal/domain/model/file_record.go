package model

import "time"

type FileRecord struct {
	ID              int64
	UserID          int64
	QuestionID      *int64
	StorageProvider string
	BucketName      string
	ObjectKey       string
	FileName        string
	FileURL         string
	FileSize        int64
	MIMEType        string
	FileType        string
	CreatedAt       time.Time
}
