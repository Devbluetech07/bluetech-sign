package config

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"gorm.io/gorm"
)

func RunSQLMigrations(db *gorm.DB, migrationsDir string) error {
	if err := db.Exec(`
		CREATE TABLE IF NOT EXISTS controle_migracoes (
			id BIGSERIAL PRIMARY KEY,
			nome_arquivo TEXT NOT NULL UNIQUE,
			executado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
		)
	`).Error; err != nil {
		return fmt.Errorf("falha ao garantir tabela controle_migracoes: %w", err)
	}

	files, err := os.ReadDir(migrationsDir)
	if err != nil {
		return fmt.Errorf("falha ao listar migracoes em %s: %w", migrationsDir, err)
	}

	var sqlFiles []string
	for _, f := range files {
		if f.IsDir() {
			continue
		}
		name := f.Name()
		if strings.HasSuffix(strings.ToLower(name), ".sql") {
			sqlFiles = append(sqlFiles, name)
		}
	}
	sort.Strings(sqlFiles)

	for _, name := range sqlFiles {
		var jaExecutada int64
		if err := db.Raw(
			"SELECT COUNT(1) FROM controle_migracoes WHERE nome_arquivo = ?",
			name,
		).Scan(&jaExecutada).Error; err != nil {
			return fmt.Errorf("falha ao checar migracao %s: %w", name, err)
		}
		if jaExecutada > 0 {
			continue
		}

		caminho := filepath.Join(migrationsDir, name)
		conteudo, err := os.ReadFile(caminho)
		if err != nil {
			return fmt.Errorf("falha ao ler migracao %s: %w", name, err)
		}

		log.Printf("Executando migracao SQL: %s", name)
		if err := db.Exec(string(conteudo)).Error; err != nil {
			return fmt.Errorf("falha ao executar migracao %s: %w", name, err)
		}

		if err := db.Exec(
			"INSERT INTO controle_migracoes (nome_arquivo) VALUES (?)",
			name,
		).Error; err != nil {
			return fmt.Errorf("falha ao registrar migracao %s: %w", name, err)
		}
	}

	return nil
}
