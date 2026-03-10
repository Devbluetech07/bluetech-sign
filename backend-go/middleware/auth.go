package middleware

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"net/http"
	"os"
	"strings"

	"backend-go/database"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
)

func authenticateByJWT(tokenStr string, c *gin.Context) bool {
	secret := os.Getenv("JWT_SECRET")
	if secret == "" {
		secret = "changeme-secret"
	}

	token, err := jwt.Parse(tokenStr, func(token *jwt.Token) (interface{}, error) {
		return []byte(secret), nil
	})
	if err != nil || !token.Valid {
		return false
	}

	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return false
	}

	userID, ok := claims["userId"].(string)
	if !ok {
		return false
	}
	email, _ := claims["email"].(string)

	c.Set("userId", userID)
	c.Set("userEmail", email)
	return true
}

func authenticateByAPIKey(tokenStr string, c *gin.Context) bool {
	if !strings.HasPrefix(tokenStr, "vl_") {
		return false
	}

	hashBytes := sha256.Sum256([]byte(tokenStr))
	hash := hex.EncodeToString(hashBytes[:])

	ctx := context.Background()
	var userID string
	err := database.Pool.QueryRow(ctx,
		`SELECT usuario_id::text
		 FROM chaves_api
		 WHERE hash_chave = $1 AND ativo = TRUE`,
		hash,
	).Scan(&userID)
	if err != nil {
		return false
	}

	// Best effort telemetry for key usage.
	_, _ = database.Pool.Exec(ctx, "UPDATE chaves_api SET ultimo_uso = NOW() WHERE hash_chave = $1", hash)

	c.Set("userId", userID)
	return true
}

func authenticateToken(tokenStr string, c *gin.Context) bool {
	allowPortalDemo := os.Getenv("ALLOW_PORTAL_DEMO_TOKEN") == "true"
	portalToken := os.Getenv("PORTAL_DEMO_TOKEN")
	if portalToken == "" {
		portalToken = "portal-demo"
	}
	if allowPortalDemo && tokenStr == portalToken {
		// Demo mode for local portal usage only.
		c.Set("userId", nil)
		c.Set("userEmail", "portal-demo@local")
		return true
	}
	return authenticateByJWT(tokenStr, c) || authenticateByAPIKey(tokenStr, c)
}

func RequireAuth() gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"message": "Token de autenticação necessário"})
			return
		}

		tokenStr := strings.TrimPrefix(authHeader, "Bearer ")
		if !authenticateToken(tokenStr, c) {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"message": "Token inválido ou expirado"})
			return
		}
		c.Next()
	}
}

func OptionalAuth() gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader != "" && strings.HasPrefix(authHeader, "Bearer ") {
			tokenStr := strings.TrimPrefix(authHeader, "Bearer ")
			if !authenticateToken(tokenStr, c) {
				c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"message": "Token inválido ou desativado"})
				return
			}
		}
		c.Next()
	}
}
