package routes

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"
	"notes/server/internal/middleware"
	"notes/server/internal/schemas"
	"notes/server/internal/services"
)

type NoteHandler struct {
	service services.NoteService
}

func RegisterNoteRoutes(r chi.Router, noteService services.NoteService, jwtSecret string) {
	handler := NoteHandler{service: noteService}

	r.Route("/api/notes", func(r chi.Router) {
		r.Use(middleware.AuthMiddleware(jwtSecret))
		r.Post("/", handler.create)
		r.Get("/", handler.list)
		r.Patch("/{noteId}", handler.update)
		r.Delete("/{noteId}", handler.delete)
	})
}

func (handler NoteHandler) create(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		middleware.WriteAuthError(w)
		return
	}

	var req schemas.CreateNoteRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid json payload", http.StatusBadRequest)
		return
	}

	resp, err := handler.service.Create(userID, req)
	if err != nil {
		http.Error(w, "failed to create note", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(resp)
}

func (handler NoteHandler) list(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		middleware.WriteAuthError(w)
		return
	}

	folderIDValue := r.URL.Query().Get("folderId")
	query := r.URL.Query().Get("q")

	var folderID *string
	if folderIDValue != "" {
		folderID = &folderIDValue
	}

	resp, err := handler.service.List(userID, folderID, query)
	if err != nil {
		http.Error(w, "failed to fetch notes", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(resp)
}

func (handler NoteHandler) update(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		middleware.WriteAuthError(w)
		return
	}

	noteID := chi.URLParam(r, "noteId")
	if noteID == "" {
		http.Error(w, "noteId is required", http.StatusBadRequest)
		return
	}

	var req schemas.UpdateNoteRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid json payload", http.StatusBadRequest)
		return
	}

	resp, err := handler.service.Update(userID, noteID, req)
	if err != nil {
		if errors.Is(err, services.ErrNoteNotFound) {
			http.Error(w, "note not found", http.StatusNotFound)
			return
		}
		http.Error(w, "failed to update note", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(resp)
}

func (handler NoteHandler) delete(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		middleware.WriteAuthError(w)
		return
	}

	noteID := chi.URLParam(r, "noteId")
	if noteID == "" {
		http.Error(w, "noteId is required", http.StatusBadRequest)
		return
	}

	err := handler.service.Delete(userID, noteID)
	if err != nil {
		if errors.Is(err, services.ErrNoteNotFound) {
			http.Error(w, "note not found", http.StatusNotFound)
			return
		}
		http.Error(w, "failed to delete note", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
