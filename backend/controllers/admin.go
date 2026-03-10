package controllers

import (
	"log"

	"github.com/gofiber/fiber/v2"
	"github.com/gustavogomes000/singproof-go/config"
	"github.com/gustavogomes000/singproof-go/models"
	"golang.org/x/crypto/bcrypt"
)

// Middlewares already checked for SuperAdmin in routes, we just implement logic here

// GetCompanies lists all tenants for the SuperAdmin
func GetCompanies(c *fiber.Ctx) error {
	var companies []models.Company
	if err := config.DB.Preload("Users").Order("created_at desc").Find(&companies).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Erro ao listar empresas"})
	}

	// Calculate document count optionally
	var results []fiber.Map
	for _, comp := range companies {
		var docCount int64
		config.DB.Model(&models.Document{}).Where("company_id = ?", comp.ID).Count(&docCount)
		
		results = append(results, fiber.Map{
			"id":             comp.ID,
			"name":           comp.Name,
			"cnpj":           comp.CNPJ,
			"plan":           comp.Plan,
			"users_count":    len(comp.Users),
			"documents_used": docCount,
			"status":         "active", // Add status column to Company model if needed in the future
			"created_at":     comp.CreatedAt,
		})
	}

	return c.JSON(fiber.Map{"companies": results})
}

// CreateCompany creates a new tenant
type CreateCompanyReq struct {
	Name     string `json:"name"`
	CNPJ     string `json:"cnpj"`
	Plan     string `json:"plan"`
	Email    string `json:"email"` // Primary owner email
	Password string `json:"password"` // Optional, if empty we generate 123456
}

func CreateCompany(c *fiber.Ctx) error {
	var req CreateCompanyReq
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Dados inválidos"})
	}

	comp := models.Company{
		Name: req.Name,
		CNPJ: req.CNPJ,
		Plan: req.Plan,
	}
	if err := config.DB.Create(&comp).Error; err != nil {
		log.Printf("Erro criar empresa: %v", err)
		return c.Status(500).JSON(fiber.Map{"error": "Erro ao registrar empresa. O CNPJ já existe?"})
	}

	// Create owner user
	pass := req.Password
	if pass == "" {
		pass = "123456"
	}
	hashedPassword, _ := bcrypt.GenerateFromPassword([]byte(pass), bcrypt.DefaultCost)
	
	owner := models.User{
		Email:     req.Email,
		Password:  string(hashedPassword),
		Role:      "company_admin",
		CompanyID: &comp.ID,
	}
	if err := config.DB.Create(&owner).Error; err != nil {
		log.Printf("Erro ao criar dono da empresa: %v", err)
	}

	return c.Status(201).JSON(fiber.Map{
		"message": "Empresa criada com sucesso",
		"company": comp,
		"default_password": pass, // Retornamos para a UI exibir
	})
}

// GetCompanyDetails
func GetCompanyDetails(c *fiber.Ctx) error {
	id := c.Params("id")
	var comp models.Company
	if err := config.DB.Preload("Users").Where("id = ?", id).First(&comp).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Empresa não encontrada"})
	}

	var documents []models.Document
	config.DB.Where("company_id = ?", id).Find(&documents)

	return c.JSON(fiber.Map{
		"company": comp,
		"users": comp.Users,
		"documents_count": len(documents),
	})
}

type AddUserReq struct {
	Email    string `json:"email"`
	Name     string `json:"name"` // Used if the model is updated
	Role     string `json:"role"` // 'company_admin' or 'user'
	Password string `json:"password"`
}

// AddCompanyUser
func AddCompanyUser(c *fiber.Ctx) error {
	id := c.Params("id")
	var comp models.Company
	if err := config.DB.Where("id = ?", id).First(&comp).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Empresa não encontrada"})
	}

	var req AddUserReq
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Dados inválidos"})
	}

	pass := req.Password
	if pass == "" {
		pass = "123456"
	}
	hashedPassword, _ := bcrypt.GenerateFromPassword([]byte(pass), bcrypt.DefaultCost)

	role := req.Role
	if role == "" {
		role = "user"
	}

	user := models.User{
		Email:     req.Email,
		Password:  string(hashedPassword),
		Role:      role,
		CompanyID: &comp.ID,
	}
	if err := config.DB.Create(&user).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Erro ao criar usuário, email já existe?"})
	}

	return c.Status(201).JSON(fiber.Map{
		"message": "Usuário criado com sucesso",
		"user": user,
		"password": pass,
	})
}

// ResetUserPassword
func ResetUserPassword(c *fiber.Ctx) error {
	userID := c.Params("id")
	var user models.User
	if err := config.DB.Where("id = ?", userID).First(&user).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Usuário não encontrado"})
	}

	// Como solicitado, simula um envio de email resetando a senha.
	// Para uso prático aqui definimos uma nova senha e retornamos.
	newPass := "reset_" + user.Email[0:3] + "!"
	hashed, _ := bcrypt.GenerateFromPassword([]byte(newPass), bcrypt.DefaultCost)
	
	user.Password = string(hashed)
	config.DB.Save(&user)

	// In a real app we would send an email. For now, we mock and return it to the admin.
	log.Printf("Simulando envio de email para %s com nova senha: %s", user.Email, newPass)

	return c.JSON(fiber.Map{
		"message": "Enviamos um email simulado para o usuário com instruções. (Senha resetada)",
		"new_temporary_password": newPass,
	})
}

// UpdateUserRoles
func UpdateUserRoles(c *fiber.Ctx) error {
	userID := c.Params("id")
	var user models.User
	if err := config.DB.Where("id = ?", userID).First(&user).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Usuário não encontrado"})
	}
	var req struct {
		Role string `json:"role"`
		Email string `json:"email"`
	}
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid body"})
	}
	
	if req.Role != "" {
		user.Role = req.Role
	}
	if req.Email != "" {
		user.Email = req.Email
	}
	
	config.DB.Save(&user)
	return c.JSON(fiber.Map{"message": "Usuário atualizado com sucesso", "user": user})
}

func DeactivateUser(c *fiber.Ctx) error {
	userID := c.Params("id")
	if err := config.DB.Where("id = ?", userID).Delete(&models.User{}).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Erro ao desativar/deletar usuário"})
	}
	return c.JSON(fiber.Map{"message": "Usuário desativado com sucesso"})
}
