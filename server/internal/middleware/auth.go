package middleware

import (
	"context"
	"encoding/json"
	"net/http"
	"strings"

	"notes/server/internal/utils"
)

type contextKey string

const userIDContextKey contextKey = "userID"

func AuthMiddleware(jwtSecret string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			header := strings.TrimSpace(r.Header.Get("Authorization"))
			if !strings.HasPrefix(header, "Bearer ") {
				WriteAuthError(w)
				return
			}

			token := strings.TrimSpace(strings.TrimPrefix(header, "Bearer "))
			claims, err := utils.ParseAuthToken(jwtSecret, token)
			if err != nil || claims.UserID == "" {
				WriteAuthError(w)
				return
			}

			ctx := context.WithValue(r.Context(), userIDContextKey, claims.UserID)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
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
