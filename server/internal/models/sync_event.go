package models

import "time"

type SyncEvent struct {
	ID         int64     `gorm:"primaryKey;autoIncrement"`
	UserID     string    `gorm:"column:user_id;type:uuid;not null;index:idx_sync_events_user_id_id,priority:1"`
	EntityType string    `gorm:"column:entity_type;type:text;not null;index:idx_sync_events_user_id_id,priority:2"`
	EntityID   string    `gorm:"column:entity_id;type:uuid;not null"`
	EventType  string    `gorm:"column:event_type;type:text;not null"`
	CreatedAt  time.Time `gorm:"type:timestamptz;not null;default:now()"`
}
