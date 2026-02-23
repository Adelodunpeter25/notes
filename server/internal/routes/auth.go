package routes

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"
	"gorm.io/gorm"
	"notes/server/internal/middleware"
	"notes/server/internal/schemas"
	"notes/server/internal/services"
)

type AuthHandler struct {
	service services.AuthService
}

func RegisterAuthRoutes(r chi.Router, authService services.AuthService, jwtSecret string) {
	handler := AuthHandler{service: authService}

	r.Route("/api/auth", func(r chi.Router) {
		r.Post("/signup", handler.signup)
		r.Post("/login", handler.login)
		r.Group(func(r chi.Router) {
			r.Use(middleware.AuthMiddleware(jwtSecret))
			r.Get("/me", handler.me)
		})
	})
}

func (handler AuthHandler) signup(w http.ResponseWriter, r *http.Request) {
	var req schemas.SignupRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid json payload", http.StatusBadRequest)
		return
	}

	resp, err := handler.service.Signup(req)
	if err != nil {
		status := authErrorStatus(err)
		http.Error(w, err.Error(), status)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(resp)
}

func (handler AuthHandler) login(w http.ResponseWriter, r *http.Request) {
	var req schemas.LoginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid json payload", http.StatusBadRequest)
		return
	}

	resp, err := handler.service.Login(req)
	if err != nil {
		status := authErrorStatus(err)
		http.Error(w, err.Error(), status)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(resp)
}

func (handler AuthHandler) me(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		middleware.WriteAuthError(w)
		return
	}

	user, err := handler.service.Me(userID)
	if err != nil {
		status := authErrorStatus(err)
		http.Error(w, err.Error(), status)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(user)
}

func authErrorStatus(err error) int {
	switch {
	case errors.Is(err, services.ErrUserExists):
		return http.StatusConflict
	case errors.Is(err, services.ErrInvalidCredentials):
		return http.StatusUnauthorized
	case errors.Is(err, gorm.ErrRecordNotFound):
		return http.StatusUnauthorized
	case errors.Is(err, services.ErrInvalidSignupPayload), errors.Is(err, services.ErrInvalidLoginPayload), errors.Is(err, services.ErrWeakPassword):
		return http.StatusBadRequest
	default:
		return http.StatusInternalServerError
	}
}
