package routes

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"gorm.io/gorm"
	"notes/server/internal/config"
	"notes/server/internal/db"
	appmiddleware "notes/server/internal/middleware"
	"notes/server/internal/services"
	"notes/server/internal/ws"
)

func NewRouter(cfg config.Config, poller *db.HealthPoller, conn *gorm.DB) http.Handler {
	r := chi.NewRouter()
	r.Use(middleware.RealIP)
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(appmiddleware.CORS)

	authService := services.NewGormAuthService(conn, cfg.JWTSecret)
	noteService := services.NewGormNoteService(conn)
	realtimeNoteService := services.NewGormRealtimeNoteService(conn, noteService)
	folderService := services.NewGormFolderService(conn)
	realtimeHub := ws.NewHub()

	RegisterHealthRoutes(r, poller)
	RegisterAuthRoutes(r, authService, cfg.JWTSecret)
	RegisterNoteRoutes(r, noteService, cfg.JWTSecret)
	RegisterFolderRoutes(r, folderService, cfg.JWTSecret)
	RegisterRealtimeNoteRoutes(r, realtimeNoteService, realtimeHub, cfg.JWTSecret)

	return r
}
