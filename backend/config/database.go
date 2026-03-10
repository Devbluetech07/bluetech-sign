package config

import (
	"log"
	"os"
	"strings"

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

	// Executa extensoes e migracoes SQL versionadas.
	queryExtensao, err := os.ReadFile("internal/infraestrutura/repositorio/consultas/habilitar_extensao_vector.sql")
	if err != nil {
		log.Fatal("Falha ao ler SQL de extensoes: ", err)
	}
	if err := db.Exec(string(queryExtensao)).Error; err != nil {
		log.Fatal("Falha ao habilitar extensoes: ", err)
	}

	if err := RunSQLMigrations(db, "internal/infraestrutura/banco/migracoes"); err != nil {
		log.Fatal("Falha ao executar migracoes SQL: ", err)
	}

	// Evita dependencia total de AutoMigrate em producao.
	appEnv := strings.ToLower(strings.TrimSpace(os.Getenv("APP_ENV")))
	autoMigrate := strings.EqualFold(os.Getenv("DB_AUTO_MIGRATE"), "true")
	if appEnv != "production" && os.Getenv("DB_AUTO_MIGRATE") == "" {
		autoMigrate = true
	}
	if autoMigrate {
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
			&models.CompanyExternalCollaborator{},
			&models.UserPermission{},
			&models.Webhook{},
			&models.WebhookDelivery{},
		)
	} else {
		log.Println("AutoMigrate desabilitado para este ambiente")
	}

	DB = db
}
