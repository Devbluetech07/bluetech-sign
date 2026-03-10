package controllers

import (
	"encoding/json"
	"os"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
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
	if strings.TrimSpace(req.ServiceType) == "" {
		return c.Status(400).JSON(fiber.Map{"message": "service_type é obrigatório"})
	}
	if strings.TrimSpace(req.ImageData) == "" {
		return c.Status(400).JSON(fiber.Map{"message": "image_data é obrigatório"})
	}

	expectedToken := strings.TrimSpace(os.Getenv("VALERIS_API_TOKEN"))
	if expectedToken == "" {
		expectedToken = "portal-demo"
	}
	authHeader := strings.TrimSpace(c.Get("Authorization"))
	authHeader = strings.TrimPrefix(authHeader, "Bearer ")
	if authHeader != expectedToken {
		return c.Status(401).JSON(fiber.Map{"message": "Token Valeris inválido"})
	}

	metadataJSON, _ := json.Marshal(req.Metadata)
	capture := models.ValerisCapture{
		ServiceType: strings.TrimSpace(req.ServiceType),
		ImageData:   req.ImageData,
		Metadata:    string(metadataJSON),
		SourceIP:    c.IP(),
		UserAgent:   c.Get("User-Agent"),
		CreatedAt:   time.Now(),
	}
	if err := config.DB.Create(&capture).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"message": "Erro ao salvar captura"})
	}

	return c.JSON(fiber.Map{
		"id":           capture.ID,
		"service_type": capture.ServiceType,
		"created_at":   capture.CreatedAt,
	})
}
