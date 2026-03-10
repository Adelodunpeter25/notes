package services

import (
	"encoding/json"
	"fmt"
	"notes/server/internal/models"
	"notes/server/internal/schemas"
	"strings"
	"time"

	"gorm.io/gorm"
)

type SyncService interface {
	Sync(userID string, req schemas.SyncRequest) (schemas.SyncResponse, error)
}

type GormSyncService struct {
	db            *gorm.DB
	noteService   NoteService
	folderService FolderService
	taskService   TaskService
}

func NewGormSyncService(db *gorm.DB, noteService NoteService, folderService FolderService, taskService TaskService) *GormSyncService {
	return &GormSyncService{
		db:            db,
		noteService:   noteService,
		folderService: folderService,
		taskService:   taskService,
	}
}

func (s *GormSyncService) Sync(userID string, req schemas.SyncRequest) (schemas.SyncResponse, error) {
	processedOpIDs := make([]string, 0)
	idMappings := make([]schemas.IDMapping, 0)
	serverTime := time.Now()

	// 1. Process outbound operations from client
	for _, op := range req.Ops {
		newID, err := s.processOperation(userID, op)
		if err == nil {
			processedOpIDs = append(processedOpIDs, op.ID)
			if newID != "" && newID != op.EntityID {
				idMappings = append(idMappings, schemas.IDMapping{
					LocalID:  op.EntityID,
					ServerID: newID,
				})
			}
		} else {
			// If entity not found, still count as processed to clear it from client outbox
			if strings.Contains(err.Error(), "not found") {
				processedOpIDs = append(processedOpIDs, op.ID)
			}
			fmt.Printf("Sync error processing op %s (entity %s): %v\n", op.ID, op.EntityID, err)
		}
	}

	// 2. Fetch changes since lastSyncAt
	var notes []models.Note
	var folders []models.Folder
	var tasks []models.Task

	lastSync := time.Time{}
	if req.LastSyncAt != nil {
		lastSync = *req.LastSyncAt
	}

	// Fetch changed entities
	s.db.Where("user_id = ? AND updated_at > ?", userID, lastSync).Find(&notes)
	s.db.Where("user_id = ? AND updated_at > ?", userID, lastSync).Find(&folders)
	s.db.Where("user_id = ? AND updated_at > ?", userID, lastSync).Find(&tasks)

	// Map to responses
	noteResps := make([]schemas.NoteResponse, 0, len(notes))
	for _, n := range notes {
		noteResps = append(noteResps, mapNoteResponse(n))
	}

	folderResps := make([]schemas.FolderResponse, 0, len(folders))
	for _, f := range folders {
		folderResps = append(folderResps, mapFolderResponse(f))
	}

	taskResps := make([]schemas.TaskResponse, 0, len(tasks))
	for _, t := range tasks {
		taskResps = append(taskResps, mapTaskResponse(t))
	}

	return schemas.SyncResponse{
		ServerTime:     serverTime,
		Notes:          noteResps,
		Folders:        folderResps,
		Tasks:          taskResps,
		ProcessedOpIDs: processedOpIDs,
		IDMappings:     idMappings,
	}, nil
}

func (s *GormSyncService) processOperation(userID string, op schemas.SyncOperation) (string, error) {
	payloadJSON, err := json.Marshal(op.Payload)
	if err != nil {
		return "", err
	}

	switch op.EntityType {
	case schemas.SyncEntityNote:
		return s.processNoteOp(userID, op, payloadJSON)
	case schemas.SyncEntityFolder:
		return s.processFolderOp(userID, op, payloadJSON)
	case schemas.SyncEntityTask:
		return s.processTaskOp(userID, op, payloadJSON)
	default:
		return "", fmt.Errorf("unknown entity type: %s", op.EntityType)
	}
}

func (s *GormSyncService) processNoteOp(userID string, op schemas.SyncOperation, payloadJSON []byte) (string, error) {
	if op.Type == schemas.SyncOpDelete {
		err := s.noteService.Delete(userID, op.EntityID)
		if err != nil && strings.Contains(err.Error(), "not found") {
			return "", nil
		}
		return "", err
	}

	var req schemas.UpdateNoteRequest
	if err := json.Unmarshal(payloadJSON, &req); err != nil {
		return "", fmt.Errorf("note unmarshal error: %v (payload: %s)", err, string(payloadJSON))
	}

	if strings.HasPrefix(op.EntityID, "local") {
		createReq := schemas.CreateNoteRequest{
			FolderID: req.FolderID,
			Title:    "",
			Content:  "",
			IsPinned: false,
		}
		if req.Title != nil {
			createReq.Title = *req.Title
		}
		if req.Content != nil {
			createReq.Content = *req.Content
		}
		if req.IsPinned != nil {
			createReq.IsPinned = *req.IsPinned
		}
		resp, err := s.noteService.Create(userID, createReq)
		if err != nil {
			return "", err
		}
		return resp.ID, nil
	}

	resp, err := s.noteService.Update(userID, op.EntityID, req)
	if err != nil && strings.Contains(err.Error(), "not found") {
		return "", nil
	}
	if err != nil {
		return "", err
	}
	return resp.ID, nil
}

func (s *GormSyncService) processFolderOp(userID string, op schemas.SyncOperation, payloadJSON []byte) (string, error) {
	if op.Type == schemas.SyncOpDelete {
		err := s.folderService.Delete(userID, op.EntityID)
		if err != nil && strings.Contains(err.Error(), "not found") {
			return "", nil
		}
		return "", err
	}

	var req schemas.UpdateFolderRequest
	if err := json.Unmarshal(payloadJSON, &req); err != nil {
		return "", fmt.Errorf("folder unmarshal error: %v (payload: %s)", err, string(payloadJSON))
	}

	if strings.HasPrefix(op.EntityID, "local") {
		resp, err := s.folderService.Create(userID, schemas.CreateFolderRequest{Name: req.Name})
		if err != nil {
			return "", err
		}
		return resp.ID, nil
	}

	resp, err := s.folderService.Update(userID, op.EntityID, req)
	if err != nil && strings.Contains(err.Error(), "not found") {
		return "", nil
	}
	if err != nil {
		return "", err
	}
	return resp.ID, nil
}

func (s *GormSyncService) processTaskOp(userID string, op schemas.SyncOperation, payloadJSON []byte) (string, error) {
	if op.Type == schemas.SyncOpDelete {
		err := s.taskService.Delete(userID, op.EntityID)
		if err != nil && strings.Contains(err.Error(), "not found") {
			return "", nil
		}
		return "", err
	}

	var req schemas.UpdateTaskRequest
	if err := json.Unmarshal(payloadJSON, &req); err != nil {
		return "", fmt.Errorf("task unmarshal error: %v (payload: %s)", err, string(payloadJSON))
	}

	if strings.HasPrefix(op.EntityID, "local") {
		createReq := schemas.CreateTaskRequest{
			Title:       "",
			Description: "",
			IsCompleted: false,
			DueDate:     req.DueDate,
		}
		if req.Title != nil {
			createReq.Title = *req.Title
		}
		if req.Description != nil {
			createReq.Description = *req.Description
		}
		if req.IsCompleted != nil {
			createReq.IsCompleted = *req.IsCompleted
		}
		resp, err := s.taskService.Create(userID, createReq)
		if err != nil {
			return "", err
		}
		return resp.ID, nil
	}

	resp, err := s.taskService.Update(userID, op.EntityID, req)
	if err != nil && strings.Contains(err.Error(), "not found") {
		return "", nil
	}
	if err != nil {
		return "", err
	}
	return resp.ID, nil
}
