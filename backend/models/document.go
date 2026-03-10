package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type Document struct {
	ID             uuid.UUID `gorm:"type:uuid;default:gen_random_uuid();primaryKey"`
	CompanyID      uuid.UUID `gorm:"type:uuid;not null"`
	Name           string    `gorm:"not null"`
	Title          string    `gorm:"not null"`
	Status         string    `gorm:"default:'draft'"`
	SignatureType  string    `gorm:"default:'electronic'"`
	Origin         string    `gorm:"default:'app'"` // app | api
	ExternalRef    string
	SourceSystem   string
	FileKey        string
	FileName       string
	FileSize       int64
	FileType       string
	SignedFileKey  string
	Message        string
	Deadline       *time.Time
	ReminderDays   int    `gorm:"default:3"`
	NotifyLanguage string `gorm:"default:'pt-BR'"`
	SequentialFlow bool   `gorm:"default:true"`
	SentAt         *time.Time
	Signers        []Signer        `gorm:"foreignKey:DocumentID"`
	Fields         []DocumentField `gorm:"foreignKey:DocumentID"`
	CreatedBy      uuid.UUID       `gorm:"type:uuid"`
	CreatedAt      time.Time
	UpdatedAt      time.Time
	DeletedAt      gorm.DeletedAt `gorm:"index"`
}

type Signer struct {
	ID                  uuid.UUID `gorm:"type:uuid;default:gen_random_uuid();primaryKey"`
	DocumentID          uuid.UUID `gorm:"type:uuid;not null"`
	Name                string    `gorm:"not null"`
	Email               string    `gorm:"not null"`
	CPF                 string
	Phone               string
	SignatureType       string `gorm:"default:'assinar'"`
	AuthMethod          string `gorm:"default:'email_token'"` // email_token, biometria_facial, sms
	Role                string `gorm:"default:'Signatário'"`
	SignOrder           int    `gorm:"default:1"`
	RequiredValidations string
	Status              string    `gorm:"default:'pending'"` // pending, sent, opened, signed, rejected
	AccessToken         uuid.UUID `gorm:"type:uuid;default:gen_random_uuid()"`
	SignToken           string
	SignTokenExpiresAt  *time.Time
	BiometriaVerified   bool `gorm:"default:false"`
	BiometriaScore      int
	BiometriaPhotoKey   string
	SelfieKey           string
	DocumentPhotoKey    string
	SignatureImageKey   string
	Message             string
	RejectionReason     string
	SignedIP            string
	SignedUserAgent     string
	OpenedAt            *time.Time
	NotifiedAt          *time.Time
	SignedAt            *time.Time
	CreatedAt           time.Time
	UpdatedAt           time.Time
}

type DocumentField struct {
	ID         uuid.UUID  `gorm:"type:uuid;default:gen_random_uuid();primaryKey"`
	DocumentID uuid.UUID  `gorm:"type:uuid;not null"`
	SignerID   *uuid.UUID `gorm:"type:uuid"`
	FieldType  string     `gorm:"not null"` // signature, date, text
	X          float64    `gorm:"not null"`
	Y          float64    `gorm:"not null"`
	Width      float64    `gorm:"not null"`
	Height     float64    `gorm:"not null"`
	Page       int        `gorm:"not null"`
	Value      string
}
