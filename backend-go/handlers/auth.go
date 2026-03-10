package handlers

import (
	"context"
	"net/http"
	"os"
	"time"

	"backend-go/database"
	"backend-go/models"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/jackc/pgx/v5"
	"golang.org/x/crypto/bcrypt"
)

type AuthRequest struct {
	Email        string `json:"email" binding:"required,email"`
	Password     string `json:"password" binding:"required,min=6"`
	NomeCompleto string `json:"nome_completo"`
}

func getSecret() string {
	secret := os.Getenv("JWT_SECRET")
	if secret == "" {
		secret = "changeme-secret"
	}
	return secret
}

func sign(userId string, email string) (string, error) {
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"userId": userId,
		"email":  email,
		"exp":    time.Now().AddDate(0, 1, 0).Unix(), // 30d
	})
	return token.SignedString([]byte(getSecret()))
}

func Register(c *gin.Context) {
	var body AuthRequest
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Dados inválidos"})
		return
	}

	ctx := context.Background()

	var existingId string
	err := database.Pool.QueryRow(ctx, "SELECT id FROM users WHERE email=$1", body.Email).Scan(&existingId)
	if err == nil {
		c.JSON(http.StatusConflict, gin.H{"message": "Email já cadastrado"})
		return
	} else if err != pgx.ErrNoRows {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Erro interno"})
		return
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(body.Password), 12)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Erro interno"})
		return
	}

	var user models.User
	err = database.Pool.QueryRow(ctx,
		"INSERT INTO users (email, password_hash, nome_completo) VALUES ($1,$2,$3) RETURNING id, email",
		body.Email, string(hash), body.NomeCompleto,
	).Scan(&user.ID, &user.Email)
	
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Erro interno"})
		return
	}

	tokenStr, _ := sign(user.ID, user.Email)
	c.JSON(http.StatusCreated, gin.H{"token": tokenStr, "user": user})
}

func Login(c *gin.Context) {
	var body AuthRequest
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Dados inválidos"})
		return
	}

	ctx := context.Background()
	var user models.User
	var passwordHash string

	err := database.Pool.QueryRow(ctx,
		"SELECT id, email, password_hash FROM users WHERE email=$1", body.Email,
	).Scan(&user.ID, &user.Email, &passwordHash)
	
	if err == pgx.ErrNoRows {
		c.JSON(http.StatusUnauthorized, gin.H{"message": "Credenciais inválidas"})
		return
	} else if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Erro interno"})
		return
	}

	if err := bcrypt.CompareHashAndPassword([]byte(passwordHash), []byte(body.Password)); err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"message": "Credenciais inválidas"})
		return
	}

	tokenStr, _ := sign(user.ID, user.Email)
	c.JSON(http.StatusOK, gin.H{"token": tokenStr, "user": user})
}

func Me(c *gin.Context) {
	userId, exists := c.Get("userId")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"message": "Token de autenticação necessário"})
		return
	}

	ctx := context.Background()
	var user models.User
	err := database.Pool.QueryRow(ctx,
		"SELECT id, email, nome_completo FROM users WHERE id=$1", userId,
	).Scan(&user.ID, &user.Email, &user.NomeCompleto)
	
	if err == pgx.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"message": "Usuário não encontrado"})
		return
	} else if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Erro interno"})
		return
	}

	c.JSON(http.StatusOK, user)
}
