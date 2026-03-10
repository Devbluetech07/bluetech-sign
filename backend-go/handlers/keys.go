package handlers

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"net/http"

	"backend-go/database"
	"backend-go/models"

	"github.com/gin-gonic/gin"
)

func GetKeys(c *gin.Context) {
	userId, _ := c.Get("userId")
	ctx := context.Background()

	rows, err := database.Pool.Query(ctx,
		`SELECT id, nome, prefixo_chave, perfil_escopo, ativo, criado_em, ultimo_uso
		 FROM chaves_api WHERE usuario_id=$1 ORDER BY criado_em DESC`, userId)
		 
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Erro interno"})
		return
	}
	defer rows.Close()

	keys := make([]models.APIKey, 0)
	for rows.Next() {
		var key models.APIKey
		err := rows.Scan(
			&key.ID, &key.Name, &key.KeyPrefix, &key.Scope,
			&key.IsActive, &key.CreatedAt, &key.LastUsedAt,
		)
		if err == nil {
			keys = append(keys, key)
		}
	}

	c.JSON(http.StatusOK, keys)
}

func CreateKey(c *gin.Context) {
	userId, _ := c.Get("userId")

	var body struct {
		Name string `json:"name" binding:"required,min=1,max=100"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Dados inválidos"})
		return
	}

	rawBytes := make([]byte, 32)
	rand.Read(rawBytes)
	rawKey := "vl_" + hex.EncodeToString(rawBytes)
	
	hashBytes := sha256.Sum256([]byte(rawKey))
	hash := hex.EncodeToString(hashBytes[:])
	
	prefix := rawKey[:12]

	ctx := context.Background()
	var key models.APIKey
	err := database.Pool.QueryRow(ctx,
		`INSERT INTO chaves_api (usuario_id, nome, prefixo_chave, hash_chave)
		 VALUES ($1,$2,$3,$4)
		 RETURNING id, nome, prefixo_chave, ativo, criado_em`,
		 userId, body.Name, prefix, hash,
	).Scan(&key.ID, &key.Name, &key.KeyPrefix, &key.IsActive, &key.CreatedAt)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Erro interno"})
		return
	}

	key.Key = rawKey
	c.JSON(http.StatusCreated, key)
}

func UpdateKey(c *gin.Context) {
	userId, _ := c.Get("userId")
	keyId := c.Param("id")

	var body struct {
		IsActive *bool `json:"is_active" binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Dados inválidos"})
		return
	}

	ctx := context.Background()
	var key models.APIKey
	err := database.Pool.QueryRow(ctx,
		`UPDATE chaves_api SET ativo=$1 WHERE id=$2 AND usuario_id=$3
		 RETURNING id, nome, prefixo_chave, ativo, criado_em`,
		 *body.IsActive, keyId, userId,
	).Scan(&key.ID, &key.Name, &key.KeyPrefix, &key.IsActive, &key.CreatedAt)

	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "Chave não encontrada"})
		return
	}

	c.JSON(http.StatusOK, key)
}

func DeleteKey(c *gin.Context) {
	userId, _ := c.Get("userId")
	keyId := c.Param("id")

	ctx := context.Background()
	_, err := database.Pool.Exec(ctx,
		"DELETE FROM chaves_api WHERE id=$1 AND usuario_id=$2",
		keyId, userId,
	)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Erro interno"})
		return
	}

	c.Status(http.StatusNoContent)
}
