package models

import "time"

type Note struct {
	ID        string    `gorm:"type:uuid;default:gen_random_uuid();primaryKey"`
	UserID    string    `gorm:"column:user_id;type:uuid;not null;index:idx_notes_user_pinned_updated,priority:1;index:idx_notes_user_folder_updated,priority:1"`
	FolderID  *string   `gorm:"column:folder_id;type:uuid;index:idx_notes_user_folder_updated,priority:2"`
	Title     string    `gorm:"type:text;not null;default:Untitled;index:idx_notes_title"`
	Content   string    `gorm:"type:text;not null;default:'';index:idx_notes_content"`
	IsPinned  bool      `gorm:"column:is_pinned;not null;default:false;index:idx_notes_user_pinned_updated,priority:2,sort:desc"`
	CreatedAt time.Time `gorm:"type:timestamptz;not null;default:now()"`
	UpdatedAt time.Time `gorm:"type:timestamptz;not null;default:now();index:idx_notes_user_pinned_updated,priority:3,sort:desc;index:idx_notes_user_folder_updated,priority:3,sort:desc"`
}
