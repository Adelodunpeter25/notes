package middleware

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"gorm.io/gorm"
	"notes/server/internal/models"
	"notes/server/internal/utils"
)

type contextKey string

const userIDContextKey contextKey = "userID"

func AuthMiddleware(jwtSecret string, conn *gorm.DB) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			userID, err := AuthenticateRequest(jwtSecret, conn, r)
			if err != nil || userID == "" {
				WriteAuthError(w)
				return
			}

			ctx := context.WithValue(r.Context(), userIDContextKey, userID)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

func AuthenticateRequest(jwtSecret string, conn *gorm.DB, r *http.Request) (string, error) {
	if conn == nil {
		return "", errors.New("db unavailable")
	}

	token, err := ExtractAuthToken(r)
	if err != nil || token == "" {
		return "", errors.New("missing token")
	}

	claims, err := utils.ParseAuthToken(jwtSecret, token)
	if err != nil || claims.UserID == "" {
		return "", errors.New("invalid token")
	}

	tokenHash := utils.HashToken(token)
	var count int64
	if err := conn.Model(&models.Token{}).
		Where("user_id = ? AND token_hash = ?", claims.UserID, tokenHash).
		Count(&count).Error; err != nil {
		return "", errors.New("failed to validate token")
	}
	if count == 0 {
		return "", errors.New("revoked token")
	}

	return claims.UserID, nil
}

func ExtractAuthToken(r *http.Request) (string, error) {
	header := strings.TrimSpace(r.Header.Get("Authorization"))
	if strings.HasPrefix(header, "Bearer ") {
		return strings.TrimSpace(strings.TrimPrefix(header, "Bearer ")), nil
	}

	queryToken := strings.TrimSpace(r.URL.Query().Get("token"))
	if queryToken != "" {
		return queryToken, nil
	}

	return "", errors.New("missing auth token")
}

func UserIDFromContext(ctx context.Context) string {
	value, ok := ctx.Value(userIDContextKey).(string)
	if !ok {
		return ""
	}
	return value
}

func WriteAuthError(w http.ResponseWriter) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusUnauthorized)
	_ = json.NewEncoder(w).Encode(map[string]string{"message": "Unauthorized"})
}
