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
	LastSyncAt *time.Time      `json:"lastSyncAt,omitempty"`
	LastCursor *string         `json:"lastCursor,omitempty"`
	Ops        []SyncOperation `json:"ops"`
}

type IDMapping struct {
	LocalID  string `json:"localId"`
	ServerID string `json:"serverId"`
}

type SyncResponse struct {
	ServerTime     time.Time        `json:"serverTime"`
	NextCursor     string           `json:"nextCursor"`
	Notes          []NoteResponse   `json:"notes"`
	Folders        []FolderResponse `json:"folders"`
	Tasks          []TaskResponse   `json:"tasks"`
	Deleted        []SyncTombstone  `json:"deleted"`
	ProcessedOpIDs []string         `json:"processedOpIds"`
	IDMappings     []IDMapping      `json:"idMappings"`
}

type SyncTombstone struct {
	EntityType SyncEntityType `json:"entityType"`
	EntityID   string         `json:"entityId"`
}
