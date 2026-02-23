package models

import "time"

type User struct {
	ID           string    `gorm:"type:uuid;default:gen_random_uuid();primaryKey"`
	Name         string    `gorm:"type:text;not null"`
	Email        string    `gorm:"type:text;not null;uniqueIndex"`
	PasswordHash string    `gorm:"column:password_hash;type:text;not null"`
	CreatedAt    time.Time `gorm:"type:timestamptz;not null;default:now()"`
}
