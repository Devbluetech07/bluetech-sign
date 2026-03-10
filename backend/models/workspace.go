package models

import (
	"time"

	"github.com/google/uuid"
)

type Contact struct {
	ID                 uuid.UUID `gorm:"type:uuid;default:gen_random_uuid();primaryKey"`
	CompanyID          uuid.UUID `gorm:"type:uuid;not null;index"`
	Name               string    `gorm:"not null"`
	Email              string    `gorm:"not null;index"`
	Phone              string
	DefaultRole        string `gorm:"default:'Signatario'"`
	DefaultAuthMethod  string `gorm:"default:'email_token'"`
	DefaultValidations string
	DocumentsCount     int `gorm:"default:0"`
	CreatedAt          time.Time
	UpdatedAt          time.Time
}

type Template struct {
	ID          uuid.UUID `gorm:"type:uuid;default:gen_random_uuid();primaryKey"`
	CompanyID   uuid.UUID `gorm:"type:uuid;not null;index"`
	Name        string    `gorm:"not null"`
	Description string
	Content     string
	Category    string
	FileKey     string
	FileName    string
	CreatedBy   uuid.UUID `gorm:"type:uuid;not null"`
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

type Department struct {
	ID          uuid.UUID `gorm:"type:uuid;default:gen_random_uuid();primaryKey"`
	CompanyID   uuid.UUID `gorm:"type:uuid;not null;index"`
	Name        string    `gorm:"not null"`
	Description string
	Color       string    `gorm:"default:'#14b8a6'"`
	CreatedBy   uuid.UUID `gorm:"type:uuid;not null"`
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

type Profile struct {
	ID                     uuid.UUID `gorm:"type:uuid;default:gen_random_uuid();primaryKey"`
	UserID                 uuid.UUID `gorm:"type:uuid;not null;uniqueIndex"`
	CompanyID              uuid.UUID `gorm:"type:uuid;not null;index"`
	FullName               string
	Hierarchy              string     `gorm:"default:'user'"` // owner | gestor | user
	DepartmentID           *uuid.UUID `gorm:"type:uuid"`
	ExternalCollaboratorID *int64
	ExternalDepartmentID   *int64
	ExternalDepartmentName string
	ExternalCargoID        *int64
	ExternalCargoName      string
	Active                 bool `gorm:"default:true"`
	AvatarURL              string
	CreatedAt              time.Time
	UpdatedAt              time.Time
}

type CompanyExternalCollaborator struct {
	ID                     uuid.UUID `gorm:"type:uuid;default:gen_random_uuid();primaryKey"`
	CompanyID              uuid.UUID `gorm:"type:uuid;not null;index:idx_company_external_collaborators_company"`
	ExternalCollaboratorID int64     `gorm:"not null;index:uidx_company_external_collaborator,unique"`
	ExternalDepartmentID   *int64
	ExternalDepartmentName string
	FullName               string `gorm:"not null"`
	Email                  string `gorm:"index:idx_company_external_collaborators_email"`
	Status                 string
	PhotoURL               string
	CargoID                *int64
	CargoName              string
	RawPayload             string `gorm:"type:text"`
	SyncedAt               time.Time
	CreatedAt              time.Time
	UpdatedAt              time.Time
}

type UserPermission struct {
	ID         uuid.UUID `gorm:"type:uuid;default:gen_random_uuid();primaryKey"`
	UserID     uuid.UUID `gorm:"type:uuid;not null;index"`
	Permission string    `gorm:"not null;index"`
	Granted    bool      `gorm:"default:true"`
	GrantedBy  uuid.UUID `gorm:"type:uuid"`
	CreatedAt  time.Time
	UpdatedAt  time.Time
}

type Webhook struct {
	ID              uuid.UUID `gorm:"type:uuid;default:gen_random_uuid();primaryKey"`
	CompanyID       uuid.UUID `gorm:"type:uuid;not null;index"`
	URL             string    `gorm:"not null"`
	Events          string
	Secret          string
	Active          bool `gorm:"default:true"`
	LastTriggeredAt *time.Time
	FailureCount    int `gorm:"default:0"`
	CreatedAt       time.Time
	UpdatedAt       time.Time
}

type WebhookDelivery struct {
	ID           uuid.UUID `gorm:"type:uuid;default:gen_random_uuid();primaryKey"`
	WebhookID    uuid.UUID `gorm:"type:uuid;not null;index"`
	Event        string    `gorm:"not null"`
	Payload      string
	StatusCode   int
	ResponseBody string
	Success      bool
	CreatedAt    time.Time
}
