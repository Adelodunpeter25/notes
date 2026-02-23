package services

import (
	"errors"
	"strings"

	"gorm.io/gorm"
	"notes/server/internal/models"
	"notes/server/internal/schemas"
)

var ErrNoteNotFound = errors.New("note not found")

type NoteService interface {
	Create(userID string, payload schemas.CreateNoteRequest) (schemas.NoteResponse, error)
	List(userID string, folderID *string, query string) ([]schemas.NoteResponse, error)
	Update(userID, noteID string, payload schemas.UpdateNoteRequest) (schemas.NoteResponse, error)
	Delete(userID, noteID string) error
}

type GormNoteService struct {
	db *gorm.DB
}

func NewGormNoteService(conn *gorm.DB) *GormNoteService {
	return &GormNoteService{db: conn}
}

func (service *GormNoteService) Create(userID string, payload schemas.CreateNoteRequest) (schemas.NoteResponse, error) {
	title := strings.TrimSpace(payload.Title)
	if title == "" {
		title = "Untitled"
	}

	note := models.Note{
		UserID:   userID,
		FolderID: payload.FolderID,
		Title:    title,
		Content:  payload.Content,
		IsPinned: payload.IsPinned,
	}
	if err := service.db.Create(&note).Error; err != nil {
		return schemas.NoteResponse{}, err
	}

	return mapNoteResponse(note), nil
}

func (service *GormNoteService) List(userID string, folderID *string, query string) ([]schemas.NoteResponse, error) {
	builder := service.db.Where("user_id = ?", userID)
	if folderID != nil && strings.TrimSpace(*folderID) != "" {
		builder = builder.Where("folder_id = ?", strings.TrimSpace(*folderID))
	}

	trimmedQuery := strings.TrimSpace(query)
	if trimmedQuery != "" {
		like := "%" + trimmedQuery + "%"
		builder = builder.Where("title ILIKE ? OR content ILIKE ?", like, like)
	}

	var notes []models.Note
	if err := builder.Order("is_pinned DESC, updated_at DESC").Find(&notes).Error; err != nil {
		return nil, err
	}

	response := make([]schemas.NoteResponse, 0, len(notes))
	for _, note := range notes {
		response = append(response, mapNoteResponse(note))
	}

	return response, nil
}

func (service *GormNoteService) Update(userID, noteID string, payload schemas.UpdateNoteRequest) (schemas.NoteResponse, error) {
	var note models.Note
	if err := service.db.Where("id = ? AND user_id = ?", noteID, userID).First(&note).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return schemas.NoteResponse{}, ErrNoteNotFound
		}
		return schemas.NoteResponse{}, err
	}

	if payload.Title != nil {
		title := strings.TrimSpace(*payload.Title)
		if title == "" {
			title = "Untitled"
		}
		note.Title = title
	}
	if payload.Content != nil {
		note.Content = *payload.Content
	}
	if payload.IsPinned != nil {
		note.IsPinned = *payload.IsPinned
	}
	if payload.FolderID != nil {
		note.FolderID = payload.FolderID
	}

	if err := service.db.Save(&note).Error; err != nil {
		return schemas.NoteResponse{}, err
	}

	return mapNoteResponse(note), nil
}

func (service *GormNoteService) Delete(userID, noteID string) error {
	result := service.db.Where("id = ? AND user_id = ?", noteID, userID).Delete(&models.Note{})
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return ErrNoteNotFound
	}
	return nil
}

func mapNoteResponse(note models.Note) schemas.NoteResponse {
	return schemas.NoteResponse{
		ID:        note.ID,
		FolderID:  note.FolderID,
		Title:     note.Title,
		Content:   note.Content,
		IsPinned:  note.IsPinned,
		CreatedAt: note.CreatedAt,
		UpdatedAt: note.UpdatedAt,
	}
}
