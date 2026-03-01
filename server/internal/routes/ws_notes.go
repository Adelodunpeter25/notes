package routes

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/gorilla/websocket"
	"gorm.io/gorm"
	appmiddleware "notes/server/internal/middleware"
	"notes/server/internal/services"
	"notes/server/internal/ws"
)

type RealtimeNoteHandler struct {
	jwtSecret string
	db        *gorm.DB
	service   services.RealtimeNoteService
	hub       *ws.Hub
	upgrader  websocket.Upgrader
}

func RegisterRealtimeNoteRoutes(
	r chi.Router,
	realtimeService services.RealtimeNoteService,
	hub *ws.Hub,
	jwtSecret string,
	conn *gorm.DB,
) {
	handler := RealtimeNoteHandler{
		jwtSecret: jwtSecret,
		db:        conn,
		service:   realtimeService,
		hub:       hub,
		upgrader: websocket.Upgrader{
			CheckOrigin: func(_ *http.Request) bool { return true },
		},
	}

	r.Get("/api/ws/notes/{noteId}", handler.connect)
}

func (handler RealtimeNoteHandler) connect(w http.ResponseWriter, r *http.Request) {
	noteID := chi.URLParam(r, "noteId")
	if noteID == "" {
		http.Error(w, "noteId is required", http.StatusBadRequest)
		return
	}

	userID, err := appmiddleware.AuthenticateRequest(handler.jwtSecret, handler.db, r)
	if err != nil || userID == "" {
		appmiddleware.WriteAuthError(w)
		return
	}

	canAccess, err := handler.service.CanAccessNote(userID, noteID)
	if err != nil {
		http.Error(w, "failed to verify note access", http.StatusInternalServerError)
		return
	}
	if !canAccess {
		http.Error(w, "note not found", http.StatusNotFound)
		return
	}

	connection, err := handler.upgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}

	client := ws.NewClient(connection, handler.hub, handler.service, userID, noteID)
	client.Start()
}
