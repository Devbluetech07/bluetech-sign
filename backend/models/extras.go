package models

import (
	"time"

	"github.com/google/uuid"
)

type ValidationStep struct {
	ID          uuid.UUID `gorm:"type:uuid;default:gen_random_uuid();primaryKey"`
	DocumentID  uuid.UUID `gorm:"type:uuid;not null"`
	SignerID    uuid.UUID `gorm:"type:uuid;not null"`
	StepType    string    `gorm:"not null"` // selfie | document_photo | selfie_with_document
	Order       int       `gorm:"default:1"`
	Required    bool      `gorm:"default:true"`
	Status      string    `gorm:"default:'pending'"` // pending | completed
	CompletedAt *time.Time
}

type AuditEntry struct {
	ID         uuid.UUID `gorm:"type:uuid;default:gen_random_uuid();primaryKey"`
	DocumentID uuid.UUID `gorm:"type:uuid;not null"`
	Action     string    `gorm:"not null"` // created, sent, viewed, signed, refused, etc
	Timestamp  time.Time `gorm:"default:now()"`
	Actor      string    `gorm:"not null"`
	Details    string
	IPAddress  string
}

type ApiKey struct {
	ID        uuid.UUID `gorm:"type:uuid;default:gen_random_uuid();primaryKey"`
	CompanyID uuid.UUID `gorm:"type:uuid;not null"`
	Name      string    `gorm:"not null"`
	KeyHash   string    `gorm:"not null"`
	Prefix    string    `gorm:"not null"`
	Scopes    string
	Active    bool `gorm:"default:true"`
	CreatedAt time.Time
	ExpiresAt *time.Time
	LastUsed  *time.Time
}

type Signature struct {
	ID            uuid.UUID `gorm:"type:uuid;default:gen_random_uuid();primaryKey"`
	SignerID      uuid.UUID `gorm:"type:uuid;not null"`
	DocumentID    uuid.UUID `gorm:"type:uuid;not null"`
	FieldID       uuid.UUID `gorm:"type:uuid;not null"`
	SignatureType string    `gorm:"not null"` // drawn | typed
	ImageBase64   string
	ImageKey      string
	TypedText     string
	UserAgent     string
	IPAddress     string
	CreatedAt     time.Time
}

type ValerisCapture struct {
	ID          uuid.UUID `gorm:"type:uuid;default:gen_random_uuid();primaryKey"`
	ServiceType string    `gorm:"not null"`
	ImageData   string    `gorm:"type:text"`
	Metadata    string    `gorm:"type:text"`
	SourceIP    string
	UserAgent   string
	CreatedAt   time.Time
}
