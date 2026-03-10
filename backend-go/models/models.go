package models

import (
	"time"
)

type User struct {
	ID           string    `json:"id"`
	Email        string    `json:"email"`
	PasswordHash string    `json:"-"`
	NomeCompleto string    `json:"nome_completo"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

type APIKey struct {
	ID         string    `json:"id"`
	UserID     string    `json:"-"`
	Name       string    `json:"name"`
	KeyPrefix  string    `json:"key_prefix"`
	Scope      string    `json:"scope"`
	IsActive   bool      `json:"is_active"`
	LastUsedAt *time.Time `json:"last_used_at"`
	CreatedAt  time.Time `json:"created_at"`
	Key        string    `json:"key,omitempty"` // Only used when sending newly created key
}

type Capture struct {
	ID                 string         `json:"id"`
	UserID             string         `json:"-"` // Omit user ID in JSON responses to match node format
	APIKeyID           *string        `json:"-"`
	ServiceType        string         `json:"service_type"`
	Status             string         `json:"status"`
	ImageData          string         `json:"image_data"`
	Latitude           *float64       `json:"latitude"`
	Longitude          *float64       `json:"longitude"`
	Endereco           *string        `json:"endereco"`
	ResultadoValidacao map[string]any `json:"resultado_validacao"`
	Metadata           map[string]any `json:"metadata"`
	CreatedAt          time.Time      `json:"created_at"`
}

type SearchCaptureResult struct {
	ID          string         `json:"id"`
	ServiceType string         `json:"service_type"`
	Metadata    map[string]any `json:"metadata"`
	CreatedAt   time.Time      `json:"created_at"`
	Similarity  float64        `json:"similarity"`
}
