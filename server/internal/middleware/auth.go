package middleware

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"notes/server/internal/utils"
)

type contextKey string

const userIDContextKey contextKey = "userID"

func AuthMiddleware(jwtSecret string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			userID, err := AuthenticateRequest(jwtSecret, r)
			if err != nil || userID == "" {
				WriteAuthError(w)
				return
			}

			ctx := context.WithValue(r.Context(), userIDContextKey, userID)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

func AuthenticateRequest(jwtSecret string, r *http.Request) (string, error) {
	token, err := ExtractAuthToken(r)
	if err != nil || token == "" {
		return "", errors.New("missing token")
	}

	claims, err := utils.ParseAuthToken(jwtSecret, token)
	if err != nil || claims.UserID == "" {
		return "", errors.New("invalid token")
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
