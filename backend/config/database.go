package config

import (
	"log"
	"os"

	"github.com/gustavogomes000/singproof-go/models"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

var DB *gorm.DB

func ConnectDB() {
	dsn := os.Getenv("DB_URL")
	if dsn == "" {
		dsn = "host=localhost user=root password=rootpassword dbname=valeris port=5432 sslmode=disable TimeZone=America/Sao_Paulo"
	}

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Info),
	})
	if err != nil {
		log.Fatal("Falha ao conectar ao banco de dados: \n", err)
	}

	log.Println("Conectado ao banco de dados com sucesso")

	// Habilitar a extensão pgvector caso não exista
	db.Exec("CREATE EXTENSION IF NOT EXISTS vector")

	log.Println("Rodando AutoMigrate...")
	db.AutoMigrate(
		&models.Company{},
		&models.User{},
		&models.Document{},
		&models.Signer{},
		&models.DocumentField{},
		&models.ValidationStep{},
		&models.AuditEntry{},
		&models.Signature{},
		&models.ValerisCapture{},
		&models.ApiKey{},
		&models.Contact{},
		&models.Template{},
		&models.Department{},
		&models.Profile{},
		&models.UserPermission{},
		&models.Webhook{},
		&models.WebhookDelivery{},
	)

	DB = db
}
