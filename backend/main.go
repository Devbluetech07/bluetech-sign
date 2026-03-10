package main

import (
	"log"
	"os"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/logger"
	"github.com/gustavogomes000/singproof-go/config"
	"github.com/gustavogomes000/singproof-go/routes"
	"github.com/joho/godotenv"
)

func main() {
	// Carrega variáveis do .env se existir (local)
	godotenv.Load()

	// Conecta ao Banco de Dados Postgres (GORM + PgVector)
	config.ConnectDB()

	// Conecta ao MinIO
	config.ConnectMinio()

	// Cria app Fiber
	app := fiber.New()

	// Middlewares globais
	app.Use(logger.New())
	app.Use(cors.New(cors.Config{
		AllowOrigins: "*", // MUDAR EM PRODUÇÃO
		AllowHeaders: "Origin, Content-Type, Accept, Authorization, x-api-key",
	}))

	// Rota de Health Check
	app.Get("/health", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{"status": "ok", "service": "Valeris API"})
	})

	// Setup de rotas Group /api/v1
	api := app.Group("/api/v1")
	routes.SetupRoutes(api)

	// UIs estáticas dos microsserviços Valeris (assinatura/selfie/documento)
	app.Static("/valeris-ui", "./static/valeris")

	// Inicia o servidor
	port := os.Getenv("PORT")
	if port == "" {
		port = "3001"
	}

	log.Printf("Iniciando Valeris API na porta %s", port)
	log.Fatal(app.Listen(":" + port))
}
