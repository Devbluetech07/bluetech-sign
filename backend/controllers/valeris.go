package controllers

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
	"github.com/gustavogomes000/singproof-go/config"
	"github.com/gustavogomes000/singproof-go/models"
)

type ValerisCaptureReq struct {
	ServiceType string                 `json:"service_type"`
	ImageData   string                 `json:"image_data"`
	Metadata    map[string]interface{} `json:"metadata"`
}

func CreateValerisCapture(c *fiber.Ctx) error {
	var req ValerisCaptureReq
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{"message": "Payload inválido"})
	}
	normalizedServiceType := normalizarTipoServicoValeris(req.ServiceType)
	if normalizedServiceType == "" {
		return c.Status(400).JSON(fiber.Map{"message": "service_type é obrigatório"})
	}
	if strings.TrimSpace(req.ImageData) == "" {
		return c.Status(400).JSON(fiber.Map{"message": "image_data é obrigatório"})
	}

	expectedToken := strings.TrimSpace(os.Getenv("VALERIS_API_TOKEN"))
	if expectedToken == "" {
		expectedToken = "vl_6c9ba69f076f4265fae820dbb8b0ac0cf3dcffb553d69ed320fcc486ba8d5773"
	}
	authHeader := strings.TrimSpace(c.Get("Authorization"))
	authHeader = strings.TrimPrefix(authHeader, "Bearer ")
	if authHeader != expectedToken {
		return c.Status(401).JSON(fiber.Map{"message": "Token Valeris inválido"})
	}

	metadataJSON, _ := json.Marshal(req.Metadata)
	capture := models.ValerisCapture{
		ServiceType: normalizedServiceType,
		ImageData:   req.ImageData,
		Metadata:    string(metadataJSON),
		SourceIP:    c.IP(),
		UserAgent:   c.Get("User-Agent"),
		CreatedAt:   time.Now(),
	}
	if err := config.DB.Create(&capture).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"message": "Erro ao salvar captura"})
	}
	processarCapturaValeris(capture, req.Metadata)

	return c.JSON(fiber.Map{
		"id":           capture.ID,
		"service_type": capture.ServiceType,
		"created_at":   capture.CreatedAt,
	})
}

func normalizarTipoServicoValeris(raw string) string {
	serviceType := strings.TrimSpace(strings.ToLower(raw))
	switch serviceType {
	case "documento", "document", "doc_photo":
		return "documento"
	case "selfie", "self":
		return "selfie"
	case "selfie-documento", "selfie_documento", "selfie_with_document":
		return "selfie-documento"
	case "assinatura", "signature":
		return "assinatura"
	default:
		return ""
	}
}

func processarCapturaValeris(capture models.ValerisCapture, metadata map[string]interface{}) {
	rawToken, ok := metadata["signing_token"]
	if !ok {
		return
	}
	signingToken := strings.TrimSpace(fmt.Sprintf("%v", rawToken))
	if signingToken == "" {
		return
	}

	signerToken, err := uuid.Parse(signingToken)
	if err != nil {
		return
	}

	var signer models.Signer
	if err := config.DB.Where("access_token = ?", signerToken).First(&signer).Error; err != nil {
		return
	}

	switch capture.ServiceType {
	case "selfie":
		signer.SelfieKey = "valeris:capture:" + capture.ID.String()
	case "documento":
		signer.DocumentPhotoKey = "valeris:capture:" + capture.ID.String()
	case "selfie-documento":
		signer.BiometriaPhotoKey = "valeris:capture:" + capture.ID.String()
	}
	_ = config.DB.Save(&signer).Error

	_ = config.DB.Create(&models.AuditEntry{
		DocumentID: signer.DocumentID,
		Action:     "valeris_capture_processed",
		Actor:      signer.Name,
		Details:    "Captura processada: " + capture.ServiceType + " (" + capture.ID.String() + ")",
		Timestamp:  time.Now(),
	}).Error
}
