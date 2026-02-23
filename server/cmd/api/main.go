package main

import (
	"context"
	"log"
	"net/http"

	"notes/server/internal/config"
	"notes/server/internal/db"
	"notes/server/internal/routes"
)

func main() {
	cfg := config.Load()
	dbCfg := db.LoadConfig()
	if dbCfg.URL == "" {
		log.Fatal("DATABASE_URL is required")
	}

	dbConn, err := db.NewPool(dbCfg)
	if err != nil {
		log.Fatalf("failed to connect to database: %v", err)
	}

	sqlDB, err := db.SQLDB(dbConn)
	if err != nil {
		log.Fatalf("failed to access sql database handle: %v", err)
	}
	defer sqlDB.Close()

	poller := db.NewHealthPoller(sqlDB, dbCfg.HealthTimeout)
	go poller.Start(context.Background(), dbCfg.HealthPollInterval)

	r := routes.NewRouter(cfg, poller, dbConn)

	addr := ":" + cfg.Port
	log.Printf("server listening on %s", addr)
	if err := http.ListenAndServe(addr, r); err != nil {
		log.Fatalf("server failed: %v", err)
	}
}
