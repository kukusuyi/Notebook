package main

import (
	"log"

	"mathnotebook/backend/internal/app"
	"mathnotebook/backend/internal/config"
	"mathnotebook/backend/internal/infra/logger"
)

func main() {
	cfg := config.Load()
	appLogger := logger.New(cfg.App.Env)

	application, err := app.Bootstrap(cfg, appLogger)
	if err != nil {
		log.Fatalf("bootstrap application: %v", err)
	}

	appLogger.Info("starting http server", "addr", application.Server.Addr)
	appLogger.Info("api docs", "url", "http://"+application.Server.Addr+"/docs")
	appLogger.Info("api docs", "url", "http://localhost:8080/docs")
	appLogger.Info("openapi json", "url", "http://"+application.Server.Addr+"/docs/openapi.json")
	if err := application.Server.ListenAndServe(); err != nil && err.Error() != "http: Server closed" {
		log.Fatalf("listen and serve: %v", err)
	}
}
