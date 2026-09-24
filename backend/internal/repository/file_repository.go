package repository

import (
	"sync"

	"github.com/kukusuyi/Questrace/backend/internal/domain/model"
)

type FileRepository interface {
	Create(record model.FileRecord) (model.FileRecord, error)
	GetByID(id int64) (model.FileRecord, bool, error)
	BindQuestion(imageID, questionID int64) error
}

type InMemoryFileRepository struct {
	mu     sync.RWMutex
	nextID int64
	items  map[int64]*model.FileRecord
}

func NewInMemoryFileRepository() *InMemoryFileRepository {
	return &InMemoryFileRepository{
		nextID: 1,
		items:  make(map[int64]*model.FileRecord),
	}
}

func (r *InMemoryFileRepository) Create(record model.FileRecord) (model.FileRecord, error) {
	r.mu.Lock()
	defer r.mu.Unlock()

	record.ID = r.nextID
	r.nextID++
	copyValue := cloneFileRecord(record)
	r.items[record.ID] = &copyValue

	return cloneFileRecord(copyValue), nil
}

func (r *InMemoryFileRepository) GetByID(id int64) (model.FileRecord, bool, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	item, ok := r.items[id]
	if !ok {
		return model.FileRecord{}, false, nil
	}

	return cloneFileRecord(*item), true, nil
}

func (r *InMemoryFileRepository) BindQuestion(imageID, questionID int64) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	item, ok := r.items[imageID]
	if !ok {
		return nil
	}

	item.QuestionID = &questionID
	return nil
}

func cloneFileRecord(record model.FileRecord) model.FileRecord {
	copyValue := record
	if record.QuestionID != nil {
		id := *record.QuestionID
		copyValue.QuestionID = &id
	}

	return copyValue
}
