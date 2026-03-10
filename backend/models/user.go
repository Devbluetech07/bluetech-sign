package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type User struct {
	ID        uuid.UUID      `gorm:"type:uuid;default:gen_random_uuid();primaryKey"`
	Email     string         `gorm:"uniqueIndex;not null"`
	Password  string         `gorm:"not null"`
	Role      string         `gorm:"default:'user'"` // superadmin, company_admin, user
	CompanyID *uuid.UUID     `gorm:"type:uuid"`
	CreatedAt time.Time
	UpdatedAt time.Time
	DeletedAt gorm.DeletedAt `gorm:"index"`
}

type Company struct {
	ID        uuid.UUID      `gorm:"type:uuid;default:gen_random_uuid();primaryKey"`
	Name      string         `gorm:"not null"`
	CNPJ      string         `gorm:"uniqueIndex"`
	Plan      string         `gorm:"default:'starter'"`
	Users     []User         `gorm:"foreignKey:CompanyID"`
	CreatedAt time.Time
	UpdatedAt time.Time
	DeletedAt gorm.DeletedAt `gorm:"index"`
}
