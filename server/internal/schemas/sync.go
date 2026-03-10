package schemas

import "time"

type SyncOpType string

const (
	SyncOpUpsert SyncOpType = "upsert"
	SyncOpDelete SyncOpType = "delete"
)

type SyncEntityType string

const (
	SyncEntityNote   SyncEntityType = "note"
	SyncEntityFolder SyncEntityType = "folder"
	SyncEntityTask   SyncEntityType = "task"
)

type SyncOperation struct {
	ID         string         `json:"id"` // Optional client op id for tracking
	Type       SyncOpType     `json:"type"`
	EntityType SyncEntityType `json:"entityType"`
	EntityID   string         `json:"entityId"`
	Payload    interface{}    `json:"payload,omitempty"`
}

type SyncRequest struct {
	LastSyncAt *time.Time      `json:"lastSyncAt"`
	Ops        []SyncOperation `json:"ops"`
}

type IDMapping struct {
	LocalID  string `json:"localId"`
	ServerID string `json:"serverId"`
}

type SyncResponse struct {
	ServerTime     time.Time        `json:"serverTime"`
	Notes          []NoteResponse   `json:"notes"`
	Folders        []FolderResponse `json:"folders"`
	Tasks          []TaskResponse   `json:"tasks"`
	ProcessedOpIDs []string         `json:"processedOpIds"`
	IDMappings     []IDMapping      `json:"idMappings"`
}
