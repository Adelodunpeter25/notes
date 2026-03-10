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

type TaskHandler struct {
	service services.TaskService
}

func RegisterTaskRoutes(r chi.Router, taskService services.TaskService, jwtSecret string, conn *gorm.DB) {
	handler := TaskHandler{service: taskService}

	r.Route("/api/tasks", func(r chi.Router) {
		r.Use(middleware.AuthMiddleware(jwtSecret, conn))
		r.Post("/", handler.create)
		r.Get("/", handler.list)
		r.Patch("/{taskId}", handler.update)
		r.Delete("/{taskId}", handler.delete)
	})
}

func (handler TaskHandler) create(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		middleware.WriteAuthError(w)
		return
	}

	var req schemas.CreateTaskRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid json payload", http.StatusBadRequest)
		return
	}

	resp, err := handler.service.Create(userID, req)
	if err != nil {
		http.Error(w, "failed to create task", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(resp)
}

func (handler TaskHandler) list(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		middleware.WriteAuthError(w)
		return
	}

	query := r.URL.Query().Get("q")

	resp, err := handler.service.List(userID, query)
	if err != nil {
		http.Error(w, "failed to fetch tasks", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(resp)
}

func (handler TaskHandler) update(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		middleware.WriteAuthError(w)
		return
	}

	taskID := chi.URLParam(r, "taskId")
	if taskID == "" {
		http.Error(w, "taskId is required", http.StatusBadRequest)
		return
	}

	var req schemas.UpdateTaskRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid json payload", http.StatusBadRequest)
		return
	}

	resp, err := handler.service.Update(userID, taskID, req)
	if err != nil {
		if errors.Is(err, services.ErrTaskNotFound) {
			http.Error(w, "task not found", http.StatusNotFound)
			return
		}
		http.Error(w, "failed to update task", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(resp)
}

func (handler TaskHandler) delete(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		middleware.WriteAuthError(w)
		return
	}

	taskID := chi.URLParam(r, "taskId")
	if taskID == "" {
		http.Error(w, "taskId is required", http.StatusBadRequest)
		return
	}

	err := handler.service.Delete(userID, taskID)
	if err != nil {
		if errors.Is(err, services.ErrTaskNotFound) {
			http.Error(w, "task not found", http.StatusNotFound)
			return
		}
		http.Error(w, "failed to delete task", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
