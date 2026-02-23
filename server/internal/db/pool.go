package db

import (
	"database/sql"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

func NewPool(cfg Config) (*gorm.DB, error) {
	return gorm.Open(postgres.Open(cfg.URL), &gorm.Config{})
}

func SQLDB(conn *gorm.DB) (*sql.DB, error) {
	return conn.DB()
}
