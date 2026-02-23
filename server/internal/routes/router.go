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
)

func NewRouter(cfg config.Config, poller *db.HealthPoller, conn *gorm.DB) http.Handler {
	r := chi.NewRouter()
	r.Use(middleware.RealIP)
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(appmiddleware.CORS)

	authService := services.NewGormAuthService(conn, cfg.JWTSecret)
	noteService := services.NewGormNoteService(conn)
	folderService := services.NewGormFolderService(conn)

	RegisterHealthRoutes(r, poller)
	RegisterAuthRoutes(r, authService)
	RegisterNoteRoutes(r, noteService, cfg.JWTSecret)
	RegisterFolderRoutes(r, folderService, cfg.JWTSecret)

	return r
}
