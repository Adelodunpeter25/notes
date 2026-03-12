package models

import "time"

type SyncOp struct {
	ID         string    `gorm:"type:uuid;default:gen_random_uuid();primaryKey"`
	UserID     string    `gorm:"column:user_id;type:uuid;not null;index:idx_sync_ops_user_op,priority:1;uniqueIndex:ux_sync_ops_user_op,priority:1"`
	OpID       string    `gorm:"column:op_id;type:text;not null;index:idx_sync_ops_user_op,priority:2;uniqueIndex:ux_sync_ops_user_op,priority:2"`
	EntityType string    `gorm:"column:entity_type;type:text;not null"`
	EntityID   string    `gorm:"column:entity_id;type:uuid"`
	Status     string    `gorm:"column:status;type:text;not null;default:'processed'"`
	CreatedAt  time.Time `gorm:"type:timestamptz;not null;default:now()"`
	UpdatedAt  time.Time `gorm:"type:timestamptz;not null;default:now()"`
}
