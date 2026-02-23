package main

import (
	"log"
	"os"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"notes/server/internal/models"
)

func main() {
	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		log.Fatal("DATABASE_URL is required")
	}

	db, err := gorm.Open(postgres.Open(databaseURL), &gorm.Config{})
	if err != nil {
		log.Fatalf("failed to connect to database: %v", err)
	}

	if err := db.Exec(`CREATE EXTENSION IF NOT EXISTS pgcrypto`).Error; err != nil {
		log.Fatalf("failed to enable pgcrypto extension: %v", err)
	}

	if err := db.AutoMigrate(&models.User{}, &models.Folder{}, &models.Note{}, &models.Token{}); err != nil {
		log.Fatalf("auto migration failed: %v", err)
	}

	log.Println("auto migration completed")
}
