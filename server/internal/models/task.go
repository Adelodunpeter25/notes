package models

import "time"

type Task struct {
	ID          string     `gorm:"type:uuid;default:gen_random_uuid();primaryKey"`
	UserID      string     `gorm:"column:user_id;type:uuid;not null;index:idx_tasks_user_updated,priority:1"`
	Title       string     `gorm:"type:text;not null;default:Untitled;index:idx_tasks_title"`
	Description string     `gorm:"type:text;not null;default:''"`
	IsCompleted bool       `gorm:"column:is_completed;not null;default:false"`
	DueDate     *time.Time `gorm:"column:due_date;type:timestamptz"`
	CreatedAt   time.Time  `gorm:"type:timestamptz;not null;default:now()"`
	UpdatedAt   time.Time  `gorm:"type:timestamptz;not null;default:now();index:idx_tasks_user_updated,priority:2,sort:desc"`
}
