package app

import (
	"database/sql"
	"fmt"
	"log/slog"
	"net/http"
	"time"

	"mathnotebook/backend/internal/config"
	"mathnotebook/backend/internal/infra/mysql"
)

type Application struct {
	Config config.Config
	Logger *slog.Logger
	Server *http.Server
}

func Bootstrap(cfg config.Config, appLogger *slog.Logger) (*Application, error) {
	db, err := mysql.Open(cfg.DB)
	if err != nil {
		return nil, err
	}
	appLogger.Info("mysql connected")
	if err := ensureDefaultUser(db, cfg.DefaultUser); err != nil {
		return nil, err
	}

	handler, err := BuildHTTPHandler(cfg, appLogger, db)
	if err != nil {
		return nil, err
	}

	server := &http.Server{
		Addr:              cfg.App.Address(),
		Handler:           handler,
		ReadHeaderTimeout: 5 * time.Second,
	}

	return &Application{
		Config: cfg,
		Logger: appLogger,
		Server: server,
	}, nil
}

func ensureDefaultUser(db *sql.DB, cfg config.DefaultUserConfig) error {
	if cfg.ID <= 0 {
		return fmt.Errorf("default user id must be positive")
	}

	_, err := db.Exec(
		`INSERT INTO user (id, username, email, password_hash, role)
		VALUES (?, ?, ?, NULL, 'user')
		ON DUPLICATE KEY UPDATE
			username = VALUES(username),
			email = VALUES(email)`,
		cfg.ID,
		cfg.Username,
		cfg.Email,
	)
	return err
}
