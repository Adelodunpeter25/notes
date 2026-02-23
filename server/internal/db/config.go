package db

import (
	"os"
	"time"
)

type Config struct {
	URL                string
	HealthPollInterval time.Duration
	HealthTimeout      time.Duration
}

func LoadConfig() Config {
	return Config{
		URL:                os.Getenv("DATABASE_URL"),
		HealthPollInterval: 30 * time.Second,
		HealthTimeout:      2 * time.Second,
	}
}
