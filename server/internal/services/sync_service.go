package services

import (
	"encoding/json"
	"errors"
	"fmt"
	"notes/server/internal/models"
	"notes/server/internal/schemas"
	"strings"
	"time"
	"strconv"

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

const (
	syncEventUpsert = "upsert"
	syncEventDelete = "delete"
)

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
	localIDMap := make(map[string]string)

	// 1. Process outbound operations from client
	for _, op := range req.Ops {
		newID, _, err := s.processOperation(userID, op, localIDMap)
		if err == nil {
			processedOpIDs = append(processedOpIDs, op.ID)
			if newID != "" && newID != op.EntityID {
				idMappings = append(idMappings, schemas.IDMapping{
					LocalID:  op.EntityID,
					ServerID: newID,
				})
				localIDMap[op.EntityID] = newID
			}
		} else {
			// If entity not found, still count as processed to clear it from client outbox
			if strings.Contains(err.Error(), "not found") {
				processedOpIDs = append(processedOpIDs, op.ID)
			}
			fmt.Printf("Sync error processing op %s (entity %s): %v\n", op.ID, op.EntityID, err)
		}
	}

	// 2. Fetch changes since cursor (or full snapshot if no cursor)
	var notes []models.Note
	var folders []models.Folder
	var tasks []models.Task
	var deleted []schemas.SyncTombstone

	cursor := parseCursor(req.LastCursor)
	if cursor > 0 {
		noteIDs, folderIDs, taskIDs, tombstones, err := s.collectChangesSinceCursor(userID, cursor)
		if err != nil {
			return schemas.SyncResponse{}, err
		}
		deleted = tombstones

		if len(noteIDs) > 0 {
			if err := s.db.Where("user_id = ? AND id IN ?", userID, noteIDs).Find(&notes).Error; err != nil {
				return schemas.SyncResponse{}, err
			}
		}
		if len(folderIDs) > 0 {
			if err := s.db.Where("user_id = ? AND id IN ?", userID, folderIDs).Find(&folders).Error; err != nil {
				return schemas.SyncResponse{}, err
			}
		}
		if len(taskIDs) > 0 {
			if err := s.db.Where("user_id = ? AND id IN ?", userID, taskIDs).Find(&tasks).Error; err != nil {
				return schemas.SyncResponse{}, err
			}
		}
	} else {
		if err := s.db.Where("user_id = ?", userID).Find(&notes).Error; err != nil {
			return schemas.SyncResponse{}, err
		}
		if err := s.db.Where("user_id = ?", userID).Find(&folders).Error; err != nil {
			return schemas.SyncResponse{}, err
		}
		if err := s.db.Where("user_id = ?", userID).Find(&tasks).Error; err != nil {
			return schemas.SyncResponse{}, err
		}
	}

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

	nextCursor, err := s.maxEventID(userID)
	if err != nil {
		return schemas.SyncResponse{}, err
	}

	return schemas.SyncResponse{
		ServerTime:     serverTime,
		NextCursor:     fmt.Sprintf("%d", nextCursor),
		Notes:          noteResps,
		Folders:        folderResps,
		Tasks:          taskResps,
		Deleted:        deleted,
		ProcessedOpIDs: processedOpIDs,
		IDMappings:     idMappings,
	}, nil
}

func (s *GormSyncService) processOperation(userID string, op schemas.SyncOperation, localIDMap map[string]string) (string, int64, error) {
	if strings.TrimSpace(op.ID) != "" {
		existing, err := s.findProcessedOp(userID, op.ID)
		if err != nil {
			return "", 0, err
		}
		if existing != nil {
			return existing.EntityID, 0, nil
		}
	}

	payloadJSON, err := json.Marshal(op.Payload)
	if err != nil {
		return "", 0, err
	}

	switch op.EntityType {
	case schemas.SyncEntityNote:
		entityID, err := s.processNoteOp(userID, op, payloadJSON, localIDMap)
		if err != nil {
			return "", 0, err
		}
		eventEntityID := entityID
		if op.Type == schemas.SyncOpDelete && eventEntityID == "" {
			eventEntityID = op.EntityID
		}
		eventID, err := s.recordEvent(userID, string(op.EntityType), eventEntityID, op.Type)
		if err != nil {
			return "", 0, err
		}
		return entityID, eventID, s.recordProcessedOp(userID, op, entityID)
	case schemas.SyncEntityFolder:
		entityID, err := s.processFolderOp(userID, op, payloadJSON)
		if err != nil {
			return "", 0, err
		}
		eventEntityID := entityID
		if op.Type == schemas.SyncOpDelete && eventEntityID == "" {
			eventEntityID = op.EntityID
		}
		eventID, err := s.recordEvent(userID, string(op.EntityType), eventEntityID, op.Type)
		if err != nil {
			return "", 0, err
		}
		return entityID, eventID, s.recordProcessedOp(userID, op, entityID)
	case schemas.SyncEntityTask:
		entityID, err := s.processTaskOp(userID, op, payloadJSON)
		if err != nil {
			return "", 0, err
		}
		eventEntityID := entityID
		if op.Type == schemas.SyncOpDelete && eventEntityID == "" {
			eventEntityID = op.EntityID
		}
		eventID, err := s.recordEvent(userID, string(op.EntityType), eventEntityID, op.Type)
		if err != nil {
			return "", 0, err
		}
		return entityID, eventID, s.recordProcessedOp(userID, op, entityID)
	default:
		return "", 0, fmt.Errorf("unknown entity type: %s", op.EntityType)
	}
}

func (s *GormSyncService) findProcessedOp(userID, opID string) (*models.SyncOp, error) {
	var record models.SyncOp
	err := s.db.Where("user_id = ? AND op_id = ?", userID, opID).First(&record).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &record, nil
}

func (s *GormSyncService) recordProcessedOp(userID string, op schemas.SyncOperation, entityID string) error {
	if strings.TrimSpace(op.ID) == "" {
		return nil
	}

	if entityID == "" {
		entityID = op.EntityID
	}

	record := models.SyncOp{
		UserID:     userID,
		OpID:       op.ID,
		EntityType: string(op.EntityType),
		EntityID:   entityID,
		Status:     "processed",
	}

	if err := s.db.Create(&record).Error; err != nil {
		if isUniqueViolation(err) {
			return nil
		}
		return err
	}
	return nil
}

func isUniqueViolation(err error) bool {
	message := strings.ToLower(err.Error())
	return strings.Contains(message, "duplicate key") ||
		strings.Contains(message, "unique constraint") ||
		strings.Contains(message, "unique violation")
}

func (s *GormSyncService) processNoteOp(userID string, op schemas.SyncOperation, payloadJSON []byte, localIDMap map[string]string) (string, error) {
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
	if req.FolderID != nil {
		folderID := strings.TrimSpace(*req.FolderID)
		if strings.HasPrefix(folderID, "local_") {
			if mapped, ok := localIDMap[folderID]; ok {
				req.FolderID = &mapped
			}
		}
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
		fixed, fixErr := normalizeTaskPayload(payloadJSON)
		if fixErr != nil {
			return "", fmt.Errorf("task unmarshal error: %v (payload: %s)", err, string(payloadJSON))
		}
		if err := json.Unmarshal(fixed, &req); err != nil {
			return "", fmt.Errorf("task unmarshal error: %v (payload: %s)", err, string(payloadJSON))
		}
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

func normalizeTaskPayload(payload []byte) ([]byte, error) {
	var raw map[string]interface{}
	if err := json.Unmarshal(payload, &raw); err != nil {
		return nil, err
	}

	titleValue, hasTitle := raw["title"]
	titleObj, isObj := titleValue.(map[string]interface{})
	if !hasTitle || !isObj {
		return payload, nil
	}

	candidateTitle, ok := titleObj["title"].(string)
	if !ok {
		return payload, nil
	}

	raw["title"] = candidateTitle
	if _, ok := raw["description"].(string); !ok {
		if desc, ok := titleObj["description"].(string); ok {
			raw["description"] = desc
		}
	}
	if _, ok := raw["isCompleted"].(bool); !ok {
		if val, ok := titleObj["isCompleted"].(bool); ok {
			raw["isCompleted"] = val
		}
	}
	if _, ok := raw["dueDate"].(string); !ok {
		if val, ok := titleObj["dueDate"].(string); ok {
			raw["dueDate"] = val
		}
	}

	return json.Marshal(raw)
}

func (s *GormSyncService) recordEvent(userID, entityType, entityID string, opType schemas.SyncOpType) (int64, error) {
	if entityID == "" {
		return 0, nil
	}

	eventType := syncEventUpsert
	if opType == schemas.SyncOpDelete {
		eventType = syncEventDelete
	}

	event := models.SyncEvent{
		UserID:     userID,
		EntityType: entityType,
		EntityID:   entityID,
		EventType:  eventType,
	}

	if err := s.db.Create(&event).Error; err != nil {
		return 0, err
	}
	return event.ID, nil
}

func (s *GormSyncService) collectChangesSinceCursor(userID string, cursor int64) ([]string, []string, []string, []schemas.SyncTombstone, error) {
	var events []models.SyncEvent
	if err := s.db.Where("user_id = ? AND id > ?", userID, cursor).Order("id ASC").Find(&events).Error; err != nil {
		return nil, nil, nil, nil, err
	}

	type latestEvent struct {
		eventType string
		entityID  string
	}

	latestByEntity := make(map[string]latestEvent)
	for _, event := range events {
		key := event.EntityType + ":" + event.EntityID
		latestByEntity[key] = latestEvent{eventType: event.EventType, entityID: event.EntityID}
	}

	noteIDs := make([]string, 0)
	folderIDs := make([]string, 0)
	taskIDs := make([]string, 0)
	deleted := make([]schemas.SyncTombstone, 0)

	for key, current := range latestByEntity {
		parts := strings.SplitN(key, ":", 2)
		entityType := parts[0]
		entityID := current.entityID

		if current.eventType == syncEventDelete {
			deleted = append(deleted, schemas.SyncTombstone{
				EntityType: schemas.SyncEntityType(entityType),
				EntityID:   entityID,
			})
			continue
		}

		switch entityType {
		case string(schemas.SyncEntityNote):
			noteIDs = append(noteIDs, entityID)
		case string(schemas.SyncEntityFolder):
			folderIDs = append(folderIDs, entityID)
		case string(schemas.SyncEntityTask):
			taskIDs = append(taskIDs, entityID)
		}
	}

	return noteIDs, folderIDs, taskIDs, deleted, nil
}

func (s *GormSyncService) maxEventID(userID string) (int64, error) {
	var maxID int64
	err := s.db.Model(&models.SyncEvent{}).
		Select("COALESCE(MAX(id), 0)").
		Where("user_id = ?", userID).
		Scan(&maxID).Error
	if err != nil {
		return 0, err
	}
	return maxID, nil
}

func parseCursor(cursor *string) int64 {
	if cursor == nil {
		return 0
	}
	trimmed := strings.TrimSpace(*cursor)
	if trimmed == "" {
		return 0
	}
	value, err := strconv.ParseInt(trimmed, 10, 64)
	if err != nil {
		return 0
	}
	return value
}
