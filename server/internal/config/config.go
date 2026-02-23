package config

import (
	"os"
	"strings"
)

type Config struct {
	Port            string
	DatabaseURL     string
	SessionNoExpiry bool
	JWTSecret       string
}

func Load() Config {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8000"
	}

	databaseURL := os.Getenv("DATABASE_URL")
	sessionNoExpiry := parseBoolDefaultTrue(os.Getenv("SESSION_NO_EXPIRY"))
	jwtSecret := os.Getenv("JWT_SECRET")
	if jwtSecret == "" {
		jwtSecret = "dev-secret-change-me"
	}

	return Config{
		Port:            port,
		DatabaseURL:     databaseURL,
		SessionNoExpiry: sessionNoExpiry,
		JWTSecret:       jwtSecret,
	}
}

func parseBoolDefaultTrue(value string) bool {
	trimmed := strings.TrimSpace(strings.ToLower(value))
	if trimmed == "" {
		return true
	}

	switch trimmed {
	case "1", "true", "yes", "on":
		return true
	case "0", "false", "no", "off":
		return false
	default:
		return true
	}
}
