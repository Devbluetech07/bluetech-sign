package handlers

import (
	"context"
	"net/http"

	"backend-go/database"

	"github.com/gin-gonic/gin"
)

func Chat(c *gin.Context) {
	userId, _ := c.Get("userId")

	var body struct {
		Prompt string `json:"prompt" binding:"required"`
	}

	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "prompt required"})
		return
	}

	ctx := context.Background()
	_, err := database.Pool.Exec(ctx,
		"INSERT INTO ai_requests (user_id, prompt) VALUES ($1,$2)",
		userId, body.Prompt,
	)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Erro interno"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"answer": "(aqui entraria a resposta do modelo)"})
}

func ProcessEmbedding(c *gin.Context) {
	var body struct {
		JobID  int    `json:"jobId" binding:"required"`
		Status string `json:"status" binding:"required"`
	}

	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "jobId e status required"})
		return
	}

	ctx := context.Background()
	_, err := database.Pool.Exec(ctx,
		"UPDATE embedding_jobs SET status=$1 WHERE id=$2",
		body.Status, body.JobID,
	)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Erro interno"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"ok": true})
}
