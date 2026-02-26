package models

import "time"

type Folder struct {
	ID        string    `gorm:"type:uuid;default:gen_random_uuid();primaryKey"`
	UserID    string    `gorm:"column:user_id;type:uuid;not null;index:idx_folders_user_created,priority:1"`
	Name      string    `gorm:"type:text;not null"`
	CreatedAt time.Time `gorm:"type:timestamptz;not null;default:now();index:idx_folders_user_created,priority:2,sort:desc"`
	UpdatedAt time.Time `gorm:"type:timestamptz;not null;default:now()"`
}
