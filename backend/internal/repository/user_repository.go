package repository

import (
	"database/sql"

	"mathnotebook/backend/internal/domain/model"
)

type UserRepository interface {
	Create(user model.User) (model.User, error)
	GetByUsername(username string) (model.User, bool, error)
	GetByEmail(email string) (model.User, bool, error)
	GetByID(id int64) (model.User, bool, error)
}

type MySQLUserRepository struct {
	db *sql.DB
}

func NewMySQLUserRepository(db *sql.DB) *MySQLUserRepository {
	return &MySQLUserRepository{db: db}
}

func (r *MySQLUserRepository) Create(user model.User) (model.User, error) {
	result, err := r.db.Exec(
		"INSERT INTO `user` (username, email, password_hash, role) VALUES (?, ?, ?, ?)",
		user.Username, user.Email, user.PasswordHash, user.Role,
	)
	if err != nil {
		return model.User{}, err
	}

	id, err := result.LastInsertId()
	if err != nil {
		return model.User{}, err
	}

	user.ID = id
	return user, nil
}

func (r *MySQLUserRepository) GetByUsername(username string) (model.User, bool, error) {
	return r.getOne("SELECT id, username, email, password_hash, role, created_at, updated_at FROM `user` WHERE username = ?", username)
}

func (r *MySQLUserRepository) GetByEmail(email string) (model.User, bool, error) {
	return r.getOne("SELECT id, username, email, password_hash, role, created_at, updated_at FROM `user` WHERE email = ?", email)
}

func (r *MySQLUserRepository) GetByID(id int64) (model.User, bool, error) {
	return r.getOne("SELECT id, username, email, password_hash, role, created_at, updated_at FROM `user` WHERE id = ?", id)
}

func (r *MySQLUserRepository) getOne(query string, arg any) (model.User, bool, error) {
	row := r.db.QueryRow(query, arg)

	var user model.User
	err := row.Scan(&user.ID, &user.Username, &user.Email, &user.PasswordHash, &user.Role, &user.CreatedAt, &user.UpdatedAt)
	if err == sql.ErrNoRows {
		return model.User{}, false, nil
	}
	if err != nil {
		return model.User{}, false, err
	}

	return user, true, nil
}
