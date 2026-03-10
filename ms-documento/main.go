package main

import (
	"bytes"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
)

type payloadEntrada struct {
	ImageData string                 `json:"image_data"`
	Metadata  map[string]interface{} `json:"metadata"`
}

type payloadBackend struct {
	ServiceType string                 `json:"service_type"`
	ImageData   string                 `json:"image_data"`
	Metadata    map[string]interface{} `json:"metadata"`
}

func main() {
	app := fiber.New()
	httpClient := &http.Client{Timeout: 20 * time.Second}

	app.Get("/health", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{"status": "ok", "servico": "ms-documento-go"})
	})

	app.Post("/processar", func(c *fiber.Ctx) error {
		var req payloadEntrada
		if err := c.BodyParser(&req); err != nil {
			return c.Status(400).JSON(fiber.Map{"erro": "payload invalido"})
		}
		if strings.TrimSpace(req.ImageData) == "" {
			return c.Status(400).JSON(fiber.Map{"erro": "image_data e obrigatorio"})
		}

		if req.Metadata == nil {
			req.Metadata = map[string]interface{}{}
		}

		if err := notificarBackendPrincipal(httpClient, payloadBackend{
			ServiceType: "documento",
			ImageData:   req.ImageData,
			Metadata:    req.Metadata,
		}); err != nil {
			log.Printf("falha ao notificar backend principal: %v", err)
			return c.Status(502).JSON(fiber.Map{"erro": "falha ao encaminhar captura"})
		}

		return c.JSON(fiber.Map{"status": "ok", "service_type": "documento"})
	})

	porta := os.Getenv("PORT")
	if strings.TrimSpace(porta) == "" {
		porta = "3000"
	}
	log.Printf("ms-documento-go iniciando na porta %s", porta)
	log.Fatal(app.Listen(":" + porta))
}

func notificarBackendPrincipal(client *http.Client, payload payloadBackend) error {
	backendURL := os.Getenv("MAIN_BACKEND_URL")
	if strings.TrimSpace(backendURL) == "" {
		backendURL = "http://backend:3001/api/v1/valeris/captures"
	}

	token := os.Getenv("VALERIS_API_TOKEN")
	if strings.TrimSpace(token) == "" {
		token = "vl_6c9ba69f076f4265fae820dbb8b0ac0cf3dcffb553d69ed320fcc486ba8d5773"
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	req, err := http.NewRequest(http.MethodPost, backendURL, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+token)

	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		return fiber.NewError(resp.StatusCode, "backend principal retornou erro")
	}
	return nil
}
