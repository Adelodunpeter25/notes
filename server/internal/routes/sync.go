package routes

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	"gorm.io/gorm"
	"notes/server/internal/middleware"
	"notes/server/internal/schemas"
	"notes/server/internal/services"
)

type SyncHandler struct {
	service services.SyncService
}

func RegisterSyncRoutes(r chi.Router, syncService services.SyncService, jwtSecret string, conn *gorm.DB) {
	handler := SyncHandler{service: syncService}

	r.Route("/api/sync", func(r chi.Router) {
		r.Use(middleware.AuthMiddleware(jwtSecret, conn))
		r.Post("/", handler.sync)
	})
}

func (h SyncHandler) sync(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		middleware.WriteAuthError(w)
		return
	}

	var req schemas.SyncRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid json payload", http.StatusBadRequest)
		return
	}

	resp, err := h.service.Sync(userID, req)
	if err != nil {
		http.Error(w, "sync failed: "+err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(resp)
}
