package models

import "time"

type Token struct {
	ID         string     `gorm:"type:uuid;default:gen_random_uuid();primaryKey"`
	UserID     string     `gorm:"column:user_id;type:uuid;not null;index"`
	TokenHash  string     `gorm:"column:token_hash;type:text;not null;uniqueIndex"`
	Device     string     `gorm:"type:text"`
	CreatedAt  time.Time  `gorm:"type:timestamptz;not null;default:now()"`
	LastUsedAt *time.Time `gorm:"column:last_used_at;type:timestamptz"`
}
