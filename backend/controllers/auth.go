package controllers

import (
	"os"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/gustavogomes000/singproof-go/config"
	"github.com/gustavogomes000/singproof-go/models"
	"golang.org/x/crypto/bcrypt"
)

type LoginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

func Login(c *fiber.Ctx) error {
	var req LoginRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid request"})
	}
	req.Email = strings.ToLower(strings.TrimSpace(req.Email))
	req.Password = strings.TrimSpace(req.Password)

	// Admin Hardcoded (Super Admin fallback)
	if req.Email == "admin@valeris.com" && req.Password == "admin123" {
		token, err := generateJWT("superadmin-id", "superadmin", nil)
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Erro ao gerar token"})
		}
		return c.JSON(fiber.Map{
			"message": "Login successful",
			"token":   token,
			"user": fiber.Map{
				"email": "admin@valeris.com",
				"role":  "superadmin",
			},
		})
	}

	// Login como empresa / usuário normal
	var user models.User
	if err := config.DB.Where("email = ?", req.Email).First(&user).Error; err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "Credenciais inválidas"})
	}

	// Verifica a senha via bcrypt
	if err := bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(req.Password)); err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "Credenciais inválidas"})
	}

	// Gera o JWT real
	companyId := ""
	if user.CompanyID != nil {
		companyId = user.CompanyID.String()
	}

	tokenString, err := generateJWT(user.ID.String(), user.Role, &companyId)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Falha na geração do token"})
	}

	return c.JSON(fiber.Map{
		"token": tokenString,
		"user": fiber.Map{
			"id":         user.ID,
			"email":      user.Email,
			"role":       user.Role,
			"company_id": companyId,
		},
	})
}

// Register cria um usuário e empresa caso seja o primeiro, útil para testar fluxos
func Register(c *fiber.Ctx) error {
	var req struct {
		Name        string `json:"name"`
		Email       string `json:"email"`
		Password    string `json:"password"`
		CompanyName string `json:"company_name"`
	}

	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid body"})
	}
	req.Email = strings.ToLower(strings.TrimSpace(req.Email))
	req.Password = strings.TrimSpace(req.Password)
	req.CompanyName = strings.TrimSpace(req.CompanyName)

	// Checa se o usuário existe
	var existing models.User
	if config.DB.Where("email = ?", req.Email).First(&existing).RowsAffected > 0 {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Email em uso"})
	}

	// Cria Empresa
	cnpjGerado := uuid.New().String()
	company := models.Company{
		ID:   uuid.New(),
		Name: req.CompanyName,
		CNPJ: cnpjGerado,
		Plan: "starter",
	}
	if err := config.DB.Create(&company).Error; err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Falha ao criar empresa"})
	}

	// Hash Senha
	hashedPass, _ := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)

	// Cria Usuário Owner
	user := models.User{
		ID:        uuid.New(),
		Email:     req.Email,
		Password:  string(hashedPass),
		Role:      "owner",
		CompanyID: &company.ID,
	}

	if err := config.DB.Create(&user).Error; err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Falha ao criar usuário"})
	}

	return c.Status(fiber.StatusCreated).JSON(fiber.Map{
		"message":    "Registrado com sucesso",
		"company_id": company.ID,
		"user_id":    user.ID,
	})
}

// GetMe retorna dados do login
func GetMe(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)
	var user models.User
	if err := config.DB.Preload("Company").Where("id = ?", userID).First(&user).Error; err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "Usuário não encontrado"})
	}

	return c.JSON(user)
}

func generateJWT(userID string, role string, companyID *string) (string, error) {
	secret := os.Getenv("JWT_SECRET")
	if secret == "" {
		secret = "valeris_super_secret_key_2026"
	}

	claims := jwt.MapClaims{
		"user_id":    userID,
		"role":       role,
		"company_id": companyID,
		"exp":        time.Now().Add(time.Hour * 72).Unix(),
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(secret))
}
