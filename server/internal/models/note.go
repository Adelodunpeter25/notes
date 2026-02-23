package models

import "time"

type Note struct {
	ID        string    `gorm:"type:uuid;default:gen_random_uuid();primaryKey"`
	UserID    string    `gorm:"column:user_id;type:uuid;not null;index"`
	FolderID  *string   `gorm:"column:folder_id;type:uuid;index"`
	Title     string    `gorm:"type:text;not null;default:Untitled"`
	Content   string    `gorm:"type:text;not null;default:''"`
	IsPinned  bool      `gorm:"column:is_pinned;not null;default:false;index"`
	CreatedAt time.Time `gorm:"type:timestamptz;not null;default:now()"`
	UpdatedAt time.Time `gorm:"type:timestamptz;not null;default:now()"`
}
