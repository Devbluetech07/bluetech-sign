package controllers

import (
	"bytes"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"io"
	"path/filepath"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
	"github.com/gustavogomes000/singproof-go/config"
	"github.com/gustavogomes000/singproof-go/models"
	"golang.org/x/crypto/bcrypt"
)

func currentCompanyID(c *fiber.Ctx) (uuid.UUID, error) {
	companyIDStr := c.Locals("company_id")
	if companyIDStr == nil || companyIDStr == "" {
		return uuid.Nil, fiber.NewError(fiber.StatusForbidden, "Acesso negado")
	}
	return uuid.Parse(companyIDStr.(string))
}

func currentUserID(c *fiber.Ctx) uuid.UUID {
	parsed, _ := uuid.Parse(c.Locals("user_id").(string))
	return parsed
}

func GetContacts(c *fiber.Ctx) error {
	companyID, err := currentCompanyID(c)
	if err != nil {
		return c.Status(403).JSON(fiber.Map{"error": err.Error()})
	}

	var contacts []models.Contact
	config.DB.Where("company_id = ?", companyID).Order("updated_at desc").Find(&contacts)

	var signers []models.Signer
	config.DB.Joins("JOIN documents ON documents.id = signers.document_id").
		Where("documents.company_id = ?", companyID).
		Find(&signers)

	byEmail := map[string]fiber.Map{}
	for _, ct := range contacts {
		emailKey := strings.ToLower(strings.TrimSpace(ct.Email))
		byEmail[emailKey] = fiber.Map{
			"id":                  ct.ID,
			"name":                ct.Name,
			"email":               ct.Email,
			"phone":               ct.Phone,
			"default_role":        ct.DefaultRole,
			"default_auth_method": ct.DefaultAuthMethod,
			"default_validations": strings.Split(strings.TrimSpace(ct.DefaultValidations), ","),
			"documents_count":     ct.DocumentsCount,
			"is_fixed_contact":    true,
		}
	}
	for _, s := range signers {
		emailKey := strings.ToLower(strings.TrimSpace(s.Email))
		if emailKey == "" {
			continue
		}
		if existing, ok := byEmail[emailKey]; ok {
			existing["documents_count"] = existing["documents_count"].(int) + 1
			byEmail[emailKey] = existing
			continue
		}
		byEmail[emailKey] = fiber.Map{
			"id":                  nil,
			"name":                s.Name,
			"email":               s.Email,
			"phone":               s.Phone,
			"default_role":        s.Role,
			"default_auth_method": s.AuthMethod,
			"default_validations": strings.Split(strings.TrimSpace(s.RequiredValidations), ","),
			"documents_count":     1,
			"is_fixed_contact":    false,
		}
	}

	out := make([]fiber.Map, 0, len(byEmail))
	for _, v := range byEmail {
		out = append(out, v)
	}
	return c.JSON(fiber.Map{"contacts": out})
}

func CreateContact(c *fiber.Ctx) error {
	companyID, err := currentCompanyID(c)
	if err != nil {
		return c.Status(403).JSON(fiber.Map{"error": err.Error()})
	}
	var req struct {
		Name               string   `json:"name"`
		Email              string   `json:"email"`
		Phone              string   `json:"phone"`
		DefaultRole        string   `json:"default_role"`
		DefaultAuthMethod  string   `json:"default_auth_method"`
		DefaultValidations []string `json:"default_validations"`
	}
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Dados inválidos"})
	}
	contact := models.Contact{
		CompanyID:          companyID,
		Name:               strings.TrimSpace(req.Name),
		Email:              strings.TrimSpace(req.Email),
		Phone:              strings.TrimSpace(req.Phone),
		DefaultRole:        strings.TrimSpace(req.DefaultRole),
		DefaultAuthMethod:  strings.TrimSpace(req.DefaultAuthMethod),
		DefaultValidations: strings.Join(req.DefaultValidations, ","),
	}
	if contact.DefaultRole == "" {
		contact.DefaultRole = "Signatario"
	}
	if contact.DefaultAuthMethod == "" {
		contact.DefaultAuthMethod = "email_token"
	}
	if contact.Name == "" || contact.Email == "" {
		return c.Status(400).JSON(fiber.Map{"error": "Nome e email são obrigatórios"})
	}
	if err := config.DB.Create(&contact).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Falha ao criar contato"})
	}
	return c.Status(201).JSON(contact)
}

func UpdateContact(c *fiber.Ctx) error {
	id, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "ID inválido"})
	}
	var req map[string]any
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Dados inválidos"})
	}
	var contact models.Contact
	if err := config.DB.First(&contact, "id = ?", id).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Contato não encontrado"})
	}
	if v, ok := req["name"].(string); ok {
		contact.Name = strings.TrimSpace(v)
	}
	if v, ok := req["phone"].(string); ok {
		contact.Phone = strings.TrimSpace(v)
	}
	if v, ok := req["default_role"].(string); ok {
		contact.DefaultRole = strings.TrimSpace(v)
	}
	if v, ok := req["default_auth_method"].(string); ok {
		contact.DefaultAuthMethod = strings.TrimSpace(v)
	}
	if arr, ok := req["default_validations"].([]any); ok {
		vals := make([]string, 0, len(arr))
		for _, item := range arr {
			if s, ok := item.(string); ok && strings.TrimSpace(s) != "" {
				vals = append(vals, strings.TrimSpace(s))
			}
		}
		contact.DefaultValidations = strings.Join(vals, ",")
	}
	config.DB.Save(&contact)
	return c.JSON(contact)
}

func DeleteContact(c *fiber.Ctx) error {
	id, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "ID inválido"})
	}
	config.DB.Delete(&models.Contact{}, "id = ?", id)
	return c.JSON(fiber.Map{"message": "Contato removido"})
}

func GetTemplates(c *fiber.Ctx) error {
	companyID, err := currentCompanyID(c)
	if err != nil {
		return c.Status(403).JSON(fiber.Map{"error": err.Error()})
	}
	var items []models.Template
	config.DB.Where("company_id = ?", companyID).Order("updated_at desc").Find(&items)
	return c.JSON(fiber.Map{"templates": items})
}

func CreateTemplate(c *fiber.Ctx) error {
	companyID, err := currentCompanyID(c)
	if err != nil {
		return c.Status(403).JSON(fiber.Map{"error": err.Error()})
	}
	userID := currentUserID(c)
	var req struct {
		Name        string `json:"name"`
		Description string `json:"description"`
		Content     string `json:"content"`
		Category    string `json:"category"`
	}
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Dados inválidos"})
	}
	if strings.TrimSpace(req.Name) == "" {
		return c.Status(400).JSON(fiber.Map{"error": "Nome obrigatório"})
	}
	item := models.Template{
		CompanyID:   companyID,
		Name:        strings.TrimSpace(req.Name),
		Description: strings.TrimSpace(req.Description),
		Content:     req.Content,
		Category:    strings.TrimSpace(req.Category),
		CreatedBy:   userID,
	}
	if err := config.DB.Create(&item).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Falha ao criar modelo"})
	}
	return c.Status(201).JSON(item)
}

func UpdateTemplate(c *fiber.Ctx) error {
	id, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "ID inválido"})
	}
	var req map[string]any
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Dados inválidos"})
	}
	var item models.Template
	if err := config.DB.First(&item, "id = ?", id).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Modelo não encontrado"})
	}
	if v, ok := req["name"].(string); ok {
		item.Name = strings.TrimSpace(v)
	}
	if v, ok := req["description"].(string); ok {
		item.Description = strings.TrimSpace(v)
	}
	if v, ok := req["content"].(string); ok {
		item.Content = v
	}
	if v, ok := req["category"].(string); ok {
		item.Category = strings.TrimSpace(v)
	}
	config.DB.Save(&item)
	return c.JSON(item)
}

func DeleteTemplate(c *fiber.Ctx) error {
	id, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "ID inválido"})
	}
	config.DB.Delete(&models.Template{}, "id = ?", id)
	return c.JSON(fiber.Map{"message": "Modelo removido"})
}

func DuplicateTemplate(c *fiber.Ctx) error {
	id, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "ID inválido"})
	}
	var item models.Template
	if err := config.DB.First(&item, "id = ?", id).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Modelo não encontrado"})
	}
	item.ID = uuid.Nil
	item.Name = item.Name + " (Cópia)"
	item.CreatedAt = time.Time{}
	item.UpdatedAt = time.Time{}
	if err := config.DB.Create(&item).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Falha ao duplicar modelo"})
	}
	return c.Status(201).JSON(item)
}

func UploadTemplateFile(c *fiber.Ctx) error {
	templateID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "ID inválido"})
	}
	var item models.Template
	if err := config.DB.First(&item, "id = ?", templateID).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Modelo não encontrado"})
	}
	fileHeader, err := c.FormFile("file")
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Arquivo é obrigatório"})
	}
	file, err := fileHeader.Open()
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Falha ao ler arquivo"})
	}
	defer file.Close()
	buf := bytes.NewBuffer(nil)
	_, _ = io.Copy(buf, file)

	ext := filepath.Ext(fileHeader.Filename)
	key := "modelos/" + item.CompanyID.String() + "/" + uuid.NewString() + ext
	if err := config.UploadToMinio(config.MinioBucket, key, buf.Bytes(), fileHeader.Size, c.Get("Content-Type")); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Falha ao salvar arquivo no storage"})
	}
	item.FileKey = key
	item.FileName = fileHeader.Filename
	config.DB.Save(&item)
	return c.JSON(item)
}

func GetDepartments(c *fiber.Ctx) error {
	companyID, err := currentCompanyID(c)
	if err != nil {
		return c.Status(403).JSON(fiber.Map{"error": err.Error()})
	}
	var deps []models.Department
	config.DB.Where("company_id = ?", companyID).Order("created_at desc").Find(&deps)
	return c.JSON(fiber.Map{"departments": deps})
}

func CreateDepartment(c *fiber.Ctx) error {
	companyID, err := currentCompanyID(c)
	if err != nil {
		return c.Status(403).JSON(fiber.Map{"error": err.Error()})
	}
	userID := currentUserID(c)
	var req struct {
		Name        string `json:"name"`
		Description string `json:"description"`
		Color       string `json:"color"`
	}
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Dados inválidos"})
	}
	if strings.TrimSpace(req.Name) == "" {
		return c.Status(400).JSON(fiber.Map{"error": "Nome é obrigatório"})
	}
	dep := models.Department{
		CompanyID:   companyID,
		Name:        strings.TrimSpace(req.Name),
		Description: strings.TrimSpace(req.Description),
		Color:       strings.TrimSpace(req.Color),
		CreatedBy:   userID,
	}
	if dep.Color == "" {
		dep.Color = "#14b8a6"
	}
	if err := config.DB.Create(&dep).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Falha ao criar departamento"})
	}
	return c.Status(201).JSON(dep)
}

func UpdateDepartment(c *fiber.Ctx) error {
	id, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "ID inválido"})
	}
	var req map[string]any
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Dados inválidos"})
	}
	var dep models.Department
	if err := config.DB.First(&dep, "id = ?", id).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Departamento não encontrado"})
	}
	if v, ok := req["name"].(string); ok {
		dep.Name = strings.TrimSpace(v)
	}
	if v, ok := req["description"].(string); ok {
		dep.Description = strings.TrimSpace(v)
	}
	if v, ok := req["color"].(string); ok {
		dep.Color = strings.TrimSpace(v)
	}
	config.DB.Save(&dep)
	return c.JSON(dep)
}

func DeleteDepartment(c *fiber.Ctx) error {
	id, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "ID inválido"})
	}
	config.DB.Delete(&models.Department{}, "id = ?", id)
	return c.JSON(fiber.Map{"message": "Departamento removido"})
}

func GetTeamUsers(c *fiber.Ctx) error {
	companyID, err := currentCompanyID(c)
	if err != nil {
		return c.Status(403).JSON(fiber.Map{"error": err.Error()})
	}
	var users []models.User
	config.DB.Where("company_id = ?", companyID).Order("created_at desc").Find(&users)
	var profiles []models.Profile
	config.DB.Where("company_id = ?", companyID).Find(&profiles)
	profileByUser := map[uuid.UUID]models.Profile{}
	for _, p := range profiles {
		profileByUser[p.UserID] = p
	}

	resp := make([]fiber.Map, 0, len(users))
	for _, u := range users {
		p := profileByUser[u.ID]
		resp = append(resp, fiber.Map{
			"id":            u.ID,
			"email":         u.Email,
			"role":          u.Role,
			"hierarchy":     p.Hierarchy,
			"department_id": p.DepartmentID,
			"full_name":     p.FullName,
			"active":        p.Active || p.ID == uuid.Nil,
		})
	}
	return c.JSON(fiber.Map{"users": resp})
}

func CreateTeamUser(c *fiber.Ctx) error {
	companyID, err := currentCompanyID(c)
	if err != nil {
		return c.Status(403).JSON(fiber.Map{"error": err.Error()})
	}
	var req struct {
		FullName     string `json:"full_name"`
		Email        string `json:"email"`
		Password     string `json:"password"`
		Hierarchy    string `json:"hierarchy"`
		DepartmentID string `json:"department_id"`
	}
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Dados inválidos"})
	}
	if req.Password == "" {
		req.Password = "123456"
	}
	hashed, _ := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	role := "user"
	if req.Hierarchy == "owner" || req.Hierarchy == "gestor" {
		role = "company_admin"
	}
	user := models.User{
		Email:     strings.TrimSpace(req.Email),
		Password:  string(hashed),
		Role:      role,
		CompanyID: &companyID,
	}
	if err := config.DB.Create(&user).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Falha ao criar usuário"})
	}
	var depID *uuid.UUID
	if parsed, err := uuid.Parse(req.DepartmentID); err == nil {
		depID = &parsed
	}
	profile := models.Profile{
		UserID:       user.ID,
		CompanyID:    companyID,
		FullName:     strings.TrimSpace(req.FullName),
		Hierarchy:    strings.TrimSpace(req.Hierarchy),
		DepartmentID: depID,
		Active:       true,
	}
	if profile.Hierarchy == "" {
		profile.Hierarchy = "user"
	}
	config.DB.Create(&profile)
	return c.Status(201).JSON(fiber.Map{"user": user, "profile": profile, "password": req.Password})
}

func UpdateTeamUser(c *fiber.Ctx) error {
	userID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "ID inválido"})
	}
	var req struct {
		Active       *bool  `json:"active"`
		Hierarchy    string `json:"hierarchy"`
		DepartmentID string `json:"department_id"`
		FullName     string `json:"full_name"`
	}
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Dados inválidos"})
	}
	var profile models.Profile
	if err := config.DB.Where("user_id = ?", userID).First(&profile).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Perfil não encontrado"})
	}
	if req.Active != nil {
		profile.Active = *req.Active
	}
	if req.Hierarchy != "" {
		profile.Hierarchy = req.Hierarchy
	}
	if req.FullName != "" {
		profile.FullName = req.FullName
	}
	if req.DepartmentID != "" {
		if parsed, err := uuid.Parse(req.DepartmentID); err == nil {
			profile.DepartmentID = &parsed
		}
	}
	config.DB.Save(&profile)
	return c.JSON(profile)
}

func GetUserPermissions(c *fiber.Ctx) error {
	userID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "ID inválido"})
	}
	var perms []models.UserPermission
	config.DB.Where("user_id = ?", userID).Find(&perms)
	return c.JSON(fiber.Map{"permissions": perms})
}

func UpsertUserPermissions(c *fiber.Ctx) error {
	userID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "ID inválido"})
	}
	actor := currentUserID(c)
	var req struct {
		Permissions []string `json:"permissions"`
	}
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Dados inválidos"})
	}
	config.DB.Where("user_id = ?", userID).Delete(&models.UserPermission{})
	for _, p := range req.Permissions {
		item := models.UserPermission{
			UserID:     userID,
			Permission: strings.TrimSpace(p),
			Granted:    true,
			GrantedBy:  actor,
		}
		if item.Permission != "" {
			config.DB.Create(&item)
		}
	}
	return c.JSON(fiber.Map{"message": "Permissões atualizadas"})
}

func GetIntegrationDocuments(c *fiber.Ctx) error {
	companyID, err := currentCompanyID(c)
	if err != nil {
		return c.Status(403).JSON(fiber.Map{"error": err.Error()})
	}
	search := strings.ToLower(strings.TrimSpace(c.Query("search")))
	status := strings.TrimSpace(c.Query("status"))

	q := config.DB.Preload("Signers").
		Where("company_id = ? AND origin = ?", companyID, "api")
	if status != "" && status != "all" {
		q = q.Where("status = ?", status)
	}
	var docs []models.Document
	q.Order("created_at desc").Find(&docs)
	if search != "" {
		filtered := make([]models.Document, 0, len(docs))
		for _, d := range docs {
			if strings.Contains(strings.ToLower(d.Name), search) || strings.Contains(strings.ToLower(d.ExternalRef), search) {
				filtered = append(filtered, d)
			}
		}
		docs = filtered
	}
	return c.JSON(fiber.Map{"documents": docs})
}

func AddIntegrationSigner(c *fiber.Ctx) error {
	docID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "ID inválido"})
	}
	var req AddSignerReq
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Dados inválidos"})
	}
	req.SignOrder = 999
	signer := models.Signer{
		DocumentID:    docID,
		Name:          req.Name,
		Email:         req.Email,
		Phone:         req.Phone,
		Role:          req.Role,
		SignatureType: "assinar",
		AuthMethod:    "email_token",
		Status:        "pending",
		SignOrder:     999,
	}
	if signer.Role == "" {
		signer.Role = "Signatario"
	}
	if err := config.DB.Create(&signer).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Falha ao adicionar signatário"})
	}
	return c.Status(201).JSON(signer)
}

func RemoveIntegrationSigner(c *fiber.Ctx) error {
	signerID, err := uuid.Parse(c.Params("signerId"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "ID inválido"})
	}
	config.DB.Delete(&models.Signer{}, "id = ?", signerID)
	return c.JSON(fiber.Map{"message": "Signatário removido"})
}

func SendIntegrationDocument(c *fiber.Ctx) error {
	return SendDocument(c)
}

func randomHex(n int) string {
	b := make([]byte, n)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

func hashKey(raw string) string {
	sum := sha256.Sum256([]byte(raw))
	return hex.EncodeToString(sum[:])
}

func GetApiKeys(c *fiber.Ctx) error {
	companyID, err := currentCompanyID(c)
	if err != nil {
		return c.Status(403).JSON(fiber.Map{"error": err.Error()})
	}
	var keys []models.ApiKey
	config.DB.Where("company_id = ?", companyID).Order("created_at desc").Find(&keys)
	return c.JSON(fiber.Map{"keys": keys})
}

func CreateApiKey(c *fiber.Ctx) error {
	companyID, err := currentCompanyID(c)
	if err != nil {
		return c.Status(403).JSON(fiber.Map{"error": err.Error()})
	}
	var req struct {
		Name   string   `json:"name"`
		Scopes []string `json:"scopes"`
	}
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Dados inválidos"})
	}
	if strings.TrimSpace(req.Name) == "" {
		req.Name = "Nova chave"
	}
	raw := "sk_" + randomHex(32)
	item := models.ApiKey{
		CompanyID: companyID,
		Name:      strings.TrimSpace(req.Name),
		KeyHash:   hashKey(raw),
		Prefix:    raw[:12],
		Scopes:    strings.Join(req.Scopes, ","),
		Active:    true,
	}
	if err := config.DB.Create(&item).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Falha ao criar chave"})
	}
	return c.Status(201).JSON(fiber.Map{"key": item, "plain_key": raw})
}

func DeleteApiKey(c *fiber.Ctx) error {
	id, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "ID inválido"})
	}
	config.DB.Delete(&models.ApiKey{}, "id = ?", id)
	return c.JSON(fiber.Map{"message": "Chave removida"})
}

func GetWebhooks(c *fiber.Ctx) error {
	companyID, err := currentCompanyID(c)
	if err != nil {
		return c.Status(403).JSON(fiber.Map{"error": err.Error()})
	}
	var hooks []models.Webhook
	config.DB.Where("company_id = ?", companyID).Order("created_at desc").Find(&hooks)
	return c.JSON(fiber.Map{"webhooks": hooks})
}

func CreateWebhook(c *fiber.Ctx) error {
	companyID, err := currentCompanyID(c)
	if err != nil {
		return c.Status(403).JSON(fiber.Map{"error": err.Error()})
	}
	var req struct {
		URL    string   `json:"url"`
		Events []string `json:"events"`
	}
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Dados inválidos"})
	}
	item := models.Webhook{
		CompanyID: companyID,
		URL:       strings.TrimSpace(req.URL),
		Events:    strings.Join(req.Events, ","),
		Secret:    randomHex(16),
		Active:    true,
	}
	if item.URL == "" {
		return c.Status(400).JSON(fiber.Map{"error": "URL é obrigatória"})
	}
	if err := config.DB.Create(&item).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Falha ao criar webhook"})
	}
	return c.Status(201).JSON(item)
}

func ToggleWebhook(c *fiber.Ctx) error {
	id, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "ID inválido"})
	}
	var hook models.Webhook
	if err := config.DB.First(&hook, "id = ?", id).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Webhook não encontrado"})
	}
	hook.Active = !hook.Active
	config.DB.Save(&hook)
	return c.JSON(hook)
}

func DeleteWebhook(c *fiber.Ctx) error {
	id, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "ID inválido"})
	}
	config.DB.Delete(&models.Webhook{}, "id = ?", id)
	return c.JSON(fiber.Map{"message": "Webhook removido"})
}
