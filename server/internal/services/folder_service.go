package services

import (
	"errors"
	"strings"

	"gorm.io/gorm"
	"notes/server/internal/models"
	"notes/server/internal/schemas"
)

var ErrFolderNotFound = errors.New("folder not found")

type FolderService interface {
	Create(userID string, payload schemas.CreateFolderRequest) (schemas.FolderResponse, error)
	List(userID string) ([]schemas.FolderResponse, error)
	Rename(userID, folderID string, payload schemas.UpdateFolderRequest) (schemas.FolderResponse, error)
	Delete(userID, folderID string) error
	ListNotes(userID, folderID string) ([]schemas.NoteResponse, error)
}

type GormFolderService struct {
	db *gorm.DB
}

func NewGormFolderService(conn *gorm.DB) *GormFolderService {
	return &GormFolderService{db: conn}
}

func (service *GormFolderService) Create(userID string, payload schemas.CreateFolderRequest) (schemas.FolderResponse, error) {
	folder := models.Folder{
		UserID: userID,
		Name:   strings.TrimSpace(payload.Name),
	}
	if err := service.db.Create(&folder).Error; err != nil {
		return schemas.FolderResponse{}, err
	}

	return schemas.FolderResponse{ID: folder.ID, Name: folder.Name, NotesCount: 0}, nil
}

func (service *GormFolderService) List(userID string) ([]schemas.FolderResponse, error) {
	type row struct {
		ID         string
		Name       string
		NotesCount int64
	}

	var rows []row
	noteCountsSubQuery := service.db.Table("notes").
		Select("folder_id, COUNT(*) AS notes_count").
		Where("user_id = ?", userID).
		Group("folder_id")

	err := service.db.Table("folders AS f").
		Select("f.id, f.name, COALESCE(nc.notes_count, 0) AS notes_count").
		Joins("LEFT JOIN (?) AS nc ON nc.folder_id = f.id", noteCountsSubQuery).
		Where("f.user_id = ?", userID).
		Order("f.created_at DESC").
		Scan(&rows).Error
	if err != nil {
		return nil, err
	}

	response := make([]schemas.FolderResponse, 0, len(rows))
	for _, current := range rows {
		response = append(response, schemas.FolderResponse{ID: current.ID, Name: current.Name, NotesCount: current.NotesCount})
	}

	return response, nil
}

func (service *GormFolderService) Rename(userID, folderID string, payload schemas.UpdateFolderRequest) (schemas.FolderResponse, error) {
	var folder models.Folder
	if err := service.db.Where("id = ? AND user_id = ?", folderID, userID).First(&folder).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return schemas.FolderResponse{}, ErrFolderNotFound
		}
		return schemas.FolderResponse{}, err
	}

	folder.Name = strings.TrimSpace(payload.Name)
	if err := service.db.Save(&folder).Error; err != nil {
		return schemas.FolderResponse{}, err
	}

	var notesCount int64
	if err := service.db.Model(&models.Note{}).Where("folder_id = ?", folder.ID).Count(&notesCount).Error; err != nil {
		return schemas.FolderResponse{}, err
	}

	return schemas.FolderResponse{ID: folder.ID, Name: folder.Name, NotesCount: notesCount}, nil
}

func (service *GormFolderService) Delete(userID, folderID string) error {
	return service.db.Transaction(func(tx *gorm.DB) error {
		result := tx.Where("id = ? AND user_id = ?", folderID, userID).Delete(&models.Folder{})
		if result.Error != nil {
			return result.Error
		}
		if result.RowsAffected == 0 {
			return ErrFolderNotFound
		}

		if err := tx.Model(&models.Note{}).
			Where("user_id = ? AND folder_id = ?", userID, folderID).
			Update("folder_id", nil).Error; err != nil {
			return err
		}

		return nil
	})
}

func (service *GormFolderService) ListNotes(userID, folderID string) ([]schemas.NoteResponse, error) {
	var folder models.Folder
	if err := service.db.Where("id = ? AND user_id = ?", folderID, userID).First(&folder).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrFolderNotFound
		}
		return nil, err
	}

	var notes []models.Note
	if err := service.db.Where("user_id = ? AND folder_id = ?", userID, folderID).Order("updated_at DESC").Find(&notes).Error; err != nil {
		return nil, err
	}

	response := make([]schemas.NoteResponse, 0, len(notes))
	for _, note := range notes {
		response = append(response, mapNoteResponse(note))
	}

	return response, nil
}
