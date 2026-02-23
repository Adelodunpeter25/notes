package routes

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	"notes/server/internal/db"
)

type HealthHandler struct {
	poller *db.HealthPoller
}

type healthResponse struct {
	Message string `json:"message"`
}

func RegisterHealthRoutes(r chi.Router, poller *db.HealthPoller) {
	handler := HealthHandler{poller: poller}

	r.Get("/", handler.root)
	r.Get("/health", handler.health)
}

func (handler HealthHandler) root(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]string{"message": "Notes service"})
}

func (handler HealthHandler) health(w http.ResponseWriter, r *http.Request) {
	if !handler.poller.IsAlive() {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusServiceUnavailable)
		_ = json.NewEncoder(w).Encode(healthResponse{
			Message: "Database unavailable",
		})
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(healthResponse{
		Message: "Health check passed",
	})
}
