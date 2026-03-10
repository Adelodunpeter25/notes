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

type FolderHandler struct {
	service services.FolderService
}

func RegisterFolderRoutes(r chi.Router, folderService services.FolderService, jwtSecret string, conn *gorm.DB) {
	handler := FolderHandler{service: folderService}

	r.Route("/api/folders", func(r chi.Router) {
		r.Use(middleware.AuthMiddleware(jwtSecret, conn))
		r.Post("/", handler.create)
		r.Get("/", handler.list)
		r.Get("/{folderId}/notes", handler.listNotes)
		r.Patch("/{folderId}", handler.update)
		r.Delete("/{folderId}", handler.delete)
	})
}

func (handler FolderHandler) create(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		middleware.WriteAuthError(w)
		return
	}

	var req schemas.CreateFolderRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid json payload", http.StatusBadRequest)
		return
	}

	resp, err := handler.service.Create(userID, req)
	if err != nil {
		http.Error(w, "failed to create folder", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(resp)
}

func (handler FolderHandler) list(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		middleware.WriteAuthError(w)
		return
	}

	resp, err := handler.service.List(userID)
	if err != nil {
		http.Error(w, "failed to fetch folders", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(resp)
}

func (handler FolderHandler) listNotes(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		middleware.WriteAuthError(w)
		return
	}

	folderID := chi.URLParam(r, "folderId")
	if folderID == "" {
		http.Error(w, "folderId is required", http.StatusBadRequest)
		return
	}

	resp, err := handler.service.ListNotes(userID, folderID)
	if err != nil {
		if errors.Is(err, services.ErrFolderNotFound) {
			http.Error(w, "folder not found", http.StatusNotFound)
			return
		}
		http.Error(w, "failed to fetch folder notes", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(resp)
}

func (handler FolderHandler) update(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		middleware.WriteAuthError(w)
		return
	}

	folderID := chi.URLParam(r, "folderId")
	if folderID == "" {
		http.Error(w, "folderId is required", http.StatusBadRequest)
		return
	}

	var req schemas.UpdateFolderRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid json payload", http.StatusBadRequest)
		return
	}

	resp, err := handler.service.Update(userID, folderID, req)
	if err != nil {
		if errors.Is(err, services.ErrFolderNotFound) {
			http.Error(w, "folder not found", http.StatusNotFound)
			return
		}
		http.Error(w, "failed to rename folder", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(resp)
}

func (handler FolderHandler) delete(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		middleware.WriteAuthError(w)
		return
	}

	folderID := chi.URLParam(r, "folderId")
	if folderID == "" {
		http.Error(w, "folderId is required", http.StatusBadRequest)
		return
	}

	err := handler.service.Delete(userID, folderID)
	if err != nil {
		if errors.Is(err, services.ErrFolderNotFound) {
			http.Error(w, "folder not found", http.StatusNotFound)
			return
		}
		http.Error(w, "failed to delete folder", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
