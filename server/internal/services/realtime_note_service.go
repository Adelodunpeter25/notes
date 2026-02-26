package services

import (
	"errors"

	"gorm.io/gorm"
	"notes/server/internal/models"
	"notes/server/internal/schemas"
	"notes/server/internal/ws"
)

type RealtimeNoteService interface {
	CanAccessNote(userID, noteID string) (bool, error)
	ApplyPatch(userID, noteID string, patch ws.PatchMessage) (schemas.NoteResponse, error)
}

type GormRealtimeNoteService struct {
	noteService NoteService
	db          *gorm.DB
}

func NewGormRealtimeNoteService(conn *gorm.DB, noteService NoteService) *GormRealtimeNoteService {
	return &GormRealtimeNoteService{
		noteService: noteService,
		db:          conn,
	}
}

func (service *GormRealtimeNoteService) CanAccessNote(userID, noteID string) (bool, error) {
	var count int64
	err := service.db.Model(&models.Note{}).
		Where("id = ? AND user_id = ?", noteID, userID).
		Count(&count).Error
	if err != nil {
		return false, err
	}
	return count > 0, nil
}

func (service *GormRealtimeNoteService) ApplyPatch(userID, noteID string, patch ws.PatchMessage) (schemas.NoteResponse, error) {
	payload := schemas.UpdateNoteRequest{
		Content:  &patch.Content,
		Title:    patch.Title,
		IsPinned: patch.IsPinned,
	}

	response, err := service.noteService.Update(userID, noteID, payload)
	if err != nil {
		if errors.Is(err, ErrNoteNotFound) {
			return schemas.NoteResponse{}, ErrNoteNotFound
		}
		return schemas.NoteResponse{}, err
	}

	return response, nil
}
