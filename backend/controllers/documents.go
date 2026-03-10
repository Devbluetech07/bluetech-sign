package controllers

import (
	"bytes"
	"context"
	"io"
	"log"
	"path/filepath"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
	"github.com/gustavogomes000/singproof-go/config"
	"github.com/gustavogomes000/singproof-go/models"
	"github.com/minio/minio-go/v7"
)

// GetDocuments list
func GetDocuments(c *fiber.Ctx) error {
	companyIDStr := c.Locals("company_id")
	if companyIDStr == nil || companyIDStr == "" {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{"error": "Acesso negado."})
	}

	companyID, _ := uuid.Parse(companyIDStr.(string))

	var docs []models.Document
	if err := config.DB.Preload("Signers").
		Where("company_id = ?", companyID).
		Order("created_at desc").
		Find(&docs).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Erro ao buscar documentos"})
	}

	return c.JSON(fiber.Map{"documents": docs})
}

func GetDocumentDetail(c *fiber.Ctx) error {
	companyIDStr := c.Locals("company_id")
	if companyIDStr == nil || companyIDStr == "" {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{"error": "Acesso negado."})
	}
	companyID, err := uuid.Parse(companyIDStr.(string))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Company inválida"})
	}
	docID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "ID de documento inválido"})
	}

	var doc models.Document
	if err := config.DB.Preload("Signers").
		Preload("Fields").
		Where("id = ? AND company_id = ?", docID, companyID).
		First(&doc).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Documento não encontrado"})
	}

	var steps []models.ValidationStep
	config.DB.Where("document_id = ?", doc.ID).Order(`"order" asc`).Find(&steps)

	var audits []models.AuditEntry
	config.DB.Where("document_id = ?", doc.ID).Order("timestamp asc").Find(&audits)

	signedCount := 0
	for _, s := range doc.Signers {
		if s.Status == "signed" {
			signedCount++
		}
	}

	return c.JSON(fiber.Map{
		"document":             doc,
		"validation_steps":     steps,
		"audit_entries":        audits,
		"signed_signers_count": signedCount,
		"total_signers_count":  len(doc.Signers),
	})
}

// UploadDocument creates a document and uploads to MinIO
func UploadDocument(c *fiber.Ctx) error {
	companyIDStr := c.Locals("company_id")
	userIDStr := c.Locals("user_id")
	if companyIDStr == nil || companyIDStr == "" {
		return c.Status(403).JSON(fiber.Map{"error": "Acesso negado"})
	}

	companyID, _ := uuid.Parse(companyIDStr.(string))
	userID, _ := uuid.Parse(userIDStr.(string))

	fileHeader, err := c.FormFile("file")
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Arquivo é obrigatório"})
	}

	docName := c.FormValue("name")
	if docName == "" {
		docName = fileHeader.Filename
	}

	file, err := fileHeader.Open()
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Erro ao ler arquivo enviado"})
	}
	defer file.Close()

	buf := bytes.NewBuffer(nil)
	if _, err := io.Copy(buf, file); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Falha ao copiar arquivo"})
	}

	ext := filepath.Ext(fileHeader.Filename)
	key := "documento/" + companyID.String() + "/" + uuid.NewString() + ext

	err = config.UploadToMinio(config.MinioBucket, key, buf.Bytes(), fileHeader.Size, "application/pdf")
	if err != nil {
		log.Printf("MinIO upload error: %v", err)
		return c.Status(500).JSON(fiber.Map{"error": "Erro ao salvar arquivo no storage"})
	}

	doc := models.Document{
		Name:      docName,
		Title:     docName,
		CompanyID: companyID,
		Status:    "draft",
		FileKey:   key,
		FileName:  fileHeader.Filename,
		FileSize:  fileHeader.Size,
		FileType:  "application/pdf",
		CreatedBy: userID,
	}

	if err := config.DB.Create(&doc).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Falha ao criar documento do banco"})
	}

	// Audit
	config.DB.Create(&models.AuditEntry{
		DocumentID: doc.ID,
		Action:     "document_uploaded",
		Actor:      userID.String(),
		Details:    "Documento enviado com sucesso",
		Timestamp:  time.Now(),
	})

	return c.Status(201).JSON(doc)
}

func CreateDocumentFromTemplate(c *fiber.Ctx) error {
	companyIDStr := c.Locals("company_id")
	userIDStr := c.Locals("user_id")
	if companyIDStr == nil || companyIDStr == "" {
		return c.Status(403).JSON(fiber.Map{"error": "Acesso negado"})
	}
	companyID, _ := uuid.Parse(companyIDStr.(string))
	userID, _ := uuid.Parse(userIDStr.(string))

	var req CreateFromTemplateReq
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Dados inválidos"})
	}
	templateID, err := uuid.Parse(req.TemplateID)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Template inválido"})
	}
	var tpl models.Template
	if err := config.DB.Where("id = ? AND company_id = ?", templateID, companyID).First(&tpl).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Template não encontrado"})
	}

	name := strings.TrimSpace(req.Name)
	if name == "" {
		name = tpl.Name
	}
	doc := models.Document{
		Name:           name,
		Title:          name,
		CompanyID:      companyID,
		Status:         "draft",
		FileKey:        tpl.FileKey,
		FileName:       tpl.FileName,
		FileType:       "application/pdf",
		Message:        req.CustomContent,
		CreatedBy:      userID,
		Origin:         "app",
		SequentialFlow: true,
	}
	if err := config.DB.Create(&doc).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Falha ao criar documento por template"})
	}
	return c.Status(201).JSON(doc)
}

type AddSignerReq struct {
	Name                string   `json:"name"`
	Email               string   `json:"email"`
	CPF                 string   `json:"cpf"`
	Phone               string   `json:"phone"`
	SignatureType       string   `json:"signature_type"` // assinar
	AuthMethod          string   `json:"auth_method"`    // email_token, biometria_facial
	Role                string   `json:"role"`
	SignOrder           int      `json:"sign_order"`
	RequiredValidations []string `json:"required_validations"`
}

type CreateFromTemplateReq struct {
	TemplateID    string `json:"template_id"`
	Name          string `json:"name"`
	CustomContent string `json:"custom_content"`
}

type AddFieldReq struct {
	SignerID  *string `json:"signer_id"`
	FieldType string  `json:"field_type"`
	X         float64 `json:"x"`
	Y         float64 `json:"y"`
	Width     float64 `json:"width"`
	Height    float64 `json:"height"`
	Page      int     `json:"page"`
	Value     string  `json:"value"`
}

type AddFieldsBatchReq struct {
	Fields []AddFieldReq `json:"fields"`
}

type ValidationStepItem struct {
	SignerID string `json:"signer_id"`
	StepType string `json:"step_type"`
	Order    int    `json:"order"`
	Required bool   `json:"required"`
}

type ValidationStepsReq struct {
	Steps []ValidationStepItem `json:"steps"`
}

type UpdateDocumentConfigReq struct {
	Message        string     `json:"message"`
	Deadline       *time.Time `json:"deadline"`
	ReminderDays   int        `json:"reminder_days"`
	NotifyLanguage string     `json:"notify_language"`
	SequentialFlow bool       `json:"sequential_flow"`
}

// AddSigner adds a user to sign inside an existing document
func AddSigner(c *fiber.Ctx) error {
	docIDStr := c.Params("id")
	docID, err := uuid.Parse(docIDStr)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "ID de documento inválido"})
	}

	var req AddSignerReq
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Dados inválidos"})
	}

	signOrder := req.SignOrder
	if signOrder <= 0 {
		var currentCount int64
		config.DB.Model(&models.Signer{}).Where("document_id = ?", docID).Count(&currentCount)
		signOrder = int(currentCount) + 1
	}

	role := strings.TrimSpace(req.Role)
	if role == "" {
		role = "Signatário"
	}

	requiredValidations := make([]string, 0, len(req.RequiredValidations))
	for _, item := range req.RequiredValidations {
		normalized := strings.TrimSpace(strings.ToLower(item))
		if normalized == "" {
			continue
		}
		requiredValidations = append(requiredValidations, normalized)
	}

	signer := models.Signer{
		DocumentID:          docID,
		Name:                req.Name,
		Email:               req.Email,
		CPF:                 req.CPF,
		Phone:               req.Phone,
		SignatureType:       req.SignatureType,
		AuthMethod:          req.AuthMethod,
		Role:                role,
		SignOrder:           signOrder,
		RequiredValidations: strings.Join(requiredValidations, ","),
		Status:              "pending",
	}

	if err := config.DB.Create(&signer).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Falha ao adicionar signatário"})
	}

	return c.Status(201).JSON(signer)
}

func SendDocument(c *fiber.Ctx) error {
	docIDStr := c.Params("id")
	docID, err := uuid.Parse(docIDStr)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "ID de documento inválido"})
	}

	var doc models.Document
	if err := config.DB.Preload("Signers").First(&doc, "id = ?", docID).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Documento não encontrado"})
	}

	if len(doc.Signers) == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "Adicione pelo menos um signatário"})
	}

	now := time.Now()
	doc.Status = "in_progress"
	doc.SentAt = &now
	config.DB.Save(&doc)

	sentCount := 0
	failedEmails := make([]string, 0)
	for _, s := range doc.Signers {
		if doc.SequentialFlow && s.SignOrder > 1 {
			continue
		}
		s.Status = "sent"
		s.NotifiedAt = &now
		config.DB.Save(&s)
		if err := sendSigningInviteEmail(doc, s, "Você recebeu um novo documento para assinatura."); err != nil {
			failedEmails = append(failedEmails, s.Email)
			continue
		}
		sentCount++
	}

	config.DB.Create(&models.AuditEntry{
		DocumentID: doc.ID,
		Action:     "document_sent",
		Actor:      "system",
		Details:    "Documento enviado para assinatura",
		Timestamp:  now,
	})

	return c.JSON(fiber.Map{
		"message":       "Documento enviado para os signatários",
		"status":        "in_progress",
		"emails_sent":   sentCount,
		"emails_failed": failedEmails,
	})
}

func GetDocumentAudit(c *fiber.Ctx) error {
	docID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "ID de documento inválido"})
	}
	var audits []models.AuditEntry
	if err := config.DB.Where("document_id = ?", docID).Order("timestamp asc").Find(&audits).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Falha ao buscar auditoria"})
	}
	return c.JSON(fiber.Map{"entries": audits})
}

func AddDocumentFields(c *fiber.Ctx) error {
	docIDStr := c.Params("id")
	docID, err := uuid.Parse(docIDStr)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "ID de documento inválido"})
	}

	var req AddFieldsBatchReq
	if err := c.BodyParser(&req); err != nil || len(req.Fields) == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "Informe os campos do documento"})
	}

	fields := make([]models.DocumentField, 0, len(req.Fields))
	for _, item := range req.Fields {
		if strings.TrimSpace(item.FieldType) == "" || item.Page <= 0 {
			continue
		}

		var signerID *uuid.UUID
		if item.SignerID != nil && strings.TrimSpace(*item.SignerID) != "" {
			parsed, err := uuid.Parse(*item.SignerID)
			if err == nil {
				signerID = &parsed
			}
		}

		fields = append(fields, models.DocumentField{
			DocumentID: docID,
			SignerID:   signerID,
			FieldType:  strings.ToLower(strings.TrimSpace(item.FieldType)),
			X:          item.X,
			Y:          item.Y,
			Width:      item.Width,
			Height:     item.Height,
			Page:       item.Page,
			Value:      item.Value,
		})
	}

	if len(fields) == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "Nenhum campo válido foi informado"})
	}

	if err := config.DB.Where("document_id = ?", docID).Delete(&models.DocumentField{}).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Falha ao limpar campos anteriores"})
	}

	if err := config.DB.Create(&fields).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Falha ao salvar campos"})
	}

	return c.Status(201).JSON(fiber.Map{"fields_count": len(fields)})
}

func CreateValidationSteps(c *fiber.Ctx) error {
	docIDStr := c.Params("id")
	docID, err := uuid.Parse(docIDStr)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "ID de documento inválido"})
	}

	var req ValidationStepsReq
	if err := c.BodyParser(&req); err != nil || len(req.Steps) == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "Informe os passos de validação"})
	}

	steps := make([]models.ValidationStep, 0, len(req.Steps))
	for _, step := range req.Steps {
		signerID, err := uuid.Parse(step.SignerID)
		if err != nil {
			continue
		}
		order := step.Order
		if order <= 0 {
			order = 1
		}
		steps = append(steps, models.ValidationStep{
			DocumentID: docID,
			SignerID:   signerID,
			StepType:   strings.TrimSpace(strings.ToLower(step.StepType)),
			Order:      order,
			Required:   step.Required,
			Status:     "pending",
		})
	}

	if len(steps) == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "Nenhum passo de validação válido"})
	}

	if err := config.DB.Where("document_id = ?", docID).Delete(&models.ValidationStep{}).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Falha ao limpar passos anteriores"})
	}
	if err := config.DB.Create(&steps).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Falha ao salvar passos de validação"})
	}

	return c.Status(201).JSON(fiber.Map{"steps_count": len(steps)})
}

func UpdateDocumentConfig(c *fiber.Ctx) error {
	docIDStr := c.Params("id")
	docID, err := uuid.Parse(docIDStr)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "ID de documento inválido"})
	}

	var req UpdateDocumentConfigReq
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Dados inválidos"})
	}

	var doc models.Document
	if err := config.DB.First(&doc, "id = ?", docID).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Documento não encontrado"})
	}

	doc.Message = strings.TrimSpace(req.Message)
	doc.Deadline = req.Deadline
	if req.ReminderDays > 0 {
		doc.ReminderDays = req.ReminderDays
	}
	if strings.TrimSpace(req.NotifyLanguage) != "" {
		doc.NotifyLanguage = req.NotifyLanguage
	}
	doc.SequentialFlow = req.SequentialFlow

	if err := config.DB.Save(&doc).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Falha ao atualizar configurações"})
	}
	return c.JSON(fiber.Map{"message": "Configurações atualizadas", "document": doc})
}

func CancelDocument(c *fiber.Ctx) error {
	docID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "ID de documento inválido"})
	}

	if err := config.DB.Model(&models.Document{}).Where("id = ?", docID).Update("status", "cancelled").Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Falha ao cancelar documento"})
	}
	return c.JSON(fiber.Map{"message": "Documento cancelado"})
}

func ResendDocument(c *fiber.Ctx) error {
	docID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "ID de documento inválido"})
	}
	var doc models.Document
	if err := config.DB.Preload("Signers").First(&doc, "id = ?", docID).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Documento não encontrado"})
	}

	now := time.Now()
	sentCount := 0
	failedEmails := make([]string, 0)
	for _, s := range doc.Signers {
		if s.Status != "signed" {
			s.Status = "sent"
			s.NotifiedAt = &now
			config.DB.Save(&s)
			if err := sendSigningInviteEmail(doc, s, "Este é um reenvio do convite para assinatura."); err != nil {
				failedEmails = append(failedEmails, s.Email)
				continue
			}
			sentCount++
		}
	}
	config.DB.Create(&models.AuditEntry{
		DocumentID: doc.ID,
		Action:     "reminder_sent",
		Actor:      "system",
		Details:    "Convite reenviado para signatários pendentes",
		Timestamp:  now,
	})
	return c.JSON(fiber.Map{
		"message":       "Documento reenviado",
		"emails_sent":   sentCount,
		"emails_failed": failedEmails,
	})
}

func DownloadDocumentByID(c *fiber.Ctx) error {
	docID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "ID de documento inválido"})
	}

	var doc models.Document
	if err := config.DB.First(&doc, "id = ?", docID).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Documento não encontrado"})
	}
	if strings.TrimSpace(doc.FileKey) == "" {
		return c.Status(404).JSON(fiber.Map{"error": "Arquivo não vinculado ao documento"})
	}

	object, err := config.MinioClient.GetObject(context.Background(), config.MinioBucket, doc.FileKey, minio.GetObjectOptions{})
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Falha ao acessar arquivo no storage"})
	}
	defer object.Close()

	data, err := io.ReadAll(object)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Falha ao ler arquivo"})
	}

	c.Set("Content-Type", doc.FileType)
	c.Set("Content-Disposition", `attachment; filename="`+doc.FileName+`"`)
	return c.Send(data)
}
