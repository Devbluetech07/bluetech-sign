package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"backend-go/database"
	"backend-go/handlers"
	"backend-go/middleware"
	"backend-go/minio_client"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
)

func main() {
	_ = godotenv.Load() // Ignore error if .env not found

	err := database.ConnectDB()
	if err != nil {
		log.Printf("Failed to connect to database initially: %v", err)
		// We retry like original Node.js node
		attempts := 0
		for attempts < 10 {
			time.Sleep(2 * time.Second)
			err = database.ConnectDB()
			if err == nil {
				break
			}
			attempts++
			log.Printf("⏳ Waiting for database... (%d/10)", attempts)
		}
		if err != nil {
			log.Fatalf("Could not connect to database after 10 attempts")
		}
	}
	defer database.Pool.Close()

	minio_client.InitMinio()

	if os.Getenv("NODE_ENV") == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	app := gin.Default()

	// 10MB limit for JSON bodies was implicitly mapped by gin, although body limit could be middleware.
	
	allowedOriginsRaw := os.Getenv("FRONTEND_URLS")
	if allowedOriginsRaw == "" {
		allowedOriginsRaw = os.Getenv("FRONTEND_URL")
	}
	allowedOrigins := make([]string, 0)
	for _, o := range strings.Split(allowedOriginsRaw, ",") {
		trimmed := strings.TrimSpace(o)
		if trimmed != "" {
			allowedOrigins = append(allowedOrigins, trimmed)
		}
	}
	if len(allowedOrigins) == 0 {
		allowedOrigins = []string{"http://localhost:3000"}
	}

	app.Use(cors.New(cors.Config{
		AllowOrigins:     allowedOrigins,
		AllowMethods:     []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Accept", "Authorization"},
		ExposeHeaders:    []string{"Content-Length"},
		AllowCredentials: true,
		MaxAge:           12 * time.Hour,
	}))

	// Allow large image payloads (base64 composite images can be 5-15MB)
	app.Use(func(c *gin.Context) {
		c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, 50<<20) // 50 MB
		c.Next()
	})

	app.GET("/health", func(c *gin.Context) {
		err := database.Pool.Ping(context.Background())
		if err != nil {
			c.JSON(http.StatusServiceUnavailable, gin.H{"status": "error", "db": "disconnected"})
			return
		}
		c.JSON(http.StatusOK, gin.H{"status": "ok", "db": "connected", "ts": time.Now().Format(time.RFC3339)})
	})

	app.GET("/health/embeddings", func(c *gin.Context) {
		ctx := context.Background()
		var pending int
		var failed int
		_ = database.Pool.QueryRow(ctx, "SELECT COUNT(*) FROM embedding_jobs WHERE status='pending'").Scan(&pending)
		_ = database.Pool.QueryRow(ctx, "SELECT COUNT(*) FROM embedding_jobs WHERE status='failed'").Scan(&failed)
		c.JSON(http.StatusOK, gin.H{
			"status":  "ok",
			"pending": pending,
			"failed":  failed,
			"ts":      time.Now().Format(time.RFC3339),
		})
	})

	api := app.Group("/api")
	{
		authRoutes := api.Group("/auth")
		{
			authRoutes.POST("/register", handlers.Register)
			authRoutes.POST("/login", handlers.Login)
			authRoutes.GET("/me", middleware.RequireAuth(), handlers.Me)
		}

		apiKeys := api.Group("/keys")
		apiKeys.Use(middleware.RequireAuth())
		{
			apiKeys.GET("/", handlers.GetKeys)
			apiKeys.POST("/", handlers.CreateKey)
			apiKeys.PATCH("/:id", handlers.UpdateKey)
			apiKeys.DELETE("/:id", handlers.DeleteKey)
		}

		capturesGroup := api.Group("/captures")
		{
			capturesGroup.POST("/", middleware.RequireAuth(), handlers.CreateCapture)
			capturesGroup.GET("/", middleware.RequireAuth(), handlers.GetCaptures)
			capturesGroup.GET("/:id", middleware.RequireAuth(), handlers.GetCapture)
			capturesGroup.POST("/search", middleware.RequireAuth(), handlers.SearchCaptures)
		}

		api.POST("/chat", middleware.RequireAuth(), handlers.Chat)
		api.POST("/embeddings/process", middleware.RequireAuth(), handlers.ProcessEmbedding)
	}

	app.NoRoute(func(c *gin.Context) {
		c.JSON(http.StatusNotFound, gin.H{"message": "Rota não encontrada"})
	})

	port := os.Getenv("PORT")
	if port == "" {
		port = "3001"
	}

	log.Printf("🚀 Valeris API running on port %s", port)
	handlers.StartEmbeddingWorker()
	app.Run("0.0.0.0:" + port)
}
