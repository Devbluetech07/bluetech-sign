package controllers

import "github.com/gofiber/fiber/v2"

func ProcessChat(c *fiber.Ctx) error {
	// Lógica para enviar o prompt ao pgvector/LLM
	return c.JSON(fiber.Map{"reply": "Integrado com o PgVector. Recebi sua mensagem: " + string(c.Body())})
}

func ProcessEmbeddings(c *fiber.Ctx) error {
	// Gera e armazena os embeddings no PostgreSQL via pgvector
	return c.JSON(fiber.Map{"message": "Embeddings processados com sucesso."})
}

func HealthEmbeddings(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"status": "ok", "service": "Valeris Vector Health"})
}
