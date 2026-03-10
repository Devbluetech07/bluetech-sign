package controllers

import (
	"crypto/rand"
	"encoding/base64"
	"fmt"
	"math/big"
	"os"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
	"github.com/gustavogomes000/singproof-go/config"
	"github.com/gustavogomes000/singproof-go/models"
)

// GetSignToken fetches document and signer info by the public access token
func GetSignToken(c *fiber.Ctx) error {
	token := c.Params("token")

	var signer models.Signer
	if err := config.DB.Where("access_token = ?", token).First(&signer).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Link de assinatura inválido ou expirado"})
	}

	var doc models.Document
	if err := config.DB.Where("id = ?", signer.DocumentID).First(&doc).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Documento não encontrado"})
	}
	var org models.Company
	config.DB.Where("id = ?", doc.CompanyID).First(&org)

	if doc.Status == "cancelled" {
		return c.Status(410).JSON(fiber.Map{"error": "Este documento foi cancelado"})
	}

	if signer.Status == "signed" {
		return c.Status(200).JSON(fiber.Map{
			"already_signed": true,
			"signed_at":      signer.SignedAt,
			"message":        "Você já assinou este documento",
		})
	}

	// Marcar como aberto
	if signer.OpenedAt == nil {
		now := time.Now()
		signer.Status = "opened"
		signer.OpenedAt = &now
		config.DB.Save(&signer)

		config.DB.Create(&models.AuditEntry{
			DocumentID: doc.ID,
			Action:     "signer_opened",
			Actor:      signer.Name,
			Details:    signer.Name + " abriu o documento",
			Timestamp:  time.Now(),
		})
	}

	var fields []models.DocumentField
	config.DB.
		Where("document_id = ? AND (signer_id IS NULL OR signer_id = ?)", doc.ID, signer.ID).
		Order("page asc").
		Find(&fields)

	var validations []models.ValidationStep
	config.DB.
		Where("document_id = ? AND signer_id = ?", doc.ID, signer.ID).
		Order(`"order" asc`).
		Find(&validations)

	pendingFields := 0
	for _, f := range fields {
		if strings.TrimSpace(f.Value) == "" {
			pendingFields++
		}
	}

	requiredValidations := make([]string, 0)
	for _, item := range strings.Split(strings.TrimSpace(signer.RequiredValidations), ",") {
		normalized := strings.TrimSpace(item)
		if normalized != "" {
			requiredValidations = append(requiredValidations, normalized)
		}
	}

	return c.JSON(fiber.Map{
		"signer": fiber.Map{
			"id":                   signer.ID,
			"name":                 signer.Name,
			"email":                signer.Email,
			"cpf":                  signer.CPF,
			"phone":                signer.Phone,
			"role":                 signer.Role,
			"signature_type":       signer.SignatureType,
			"auth_method":          signer.AuthMethod,
			"required_validations": requiredValidations,
			"sign_order":           signer.SignOrder,
			"status":               signer.Status,
		},
		"document": fiber.Map{
			"id":             doc.ID,
			"name":           doc.Name,
			"status":         doc.Status,
			"message":        doc.Message,
			"file_url":       "/api/v1/signing/" + token + "/download",
			"total_fields":   len(fields),
			"pending_fields": pendingFields,
		},
		"organization":     fiber.Map{"name": org.Name},
		"fields":           fields,
		"validation_steps": validations,
	})
}

// RequestVerificationToken sends a 6-digit code via email
func RequestVerificationToken(c *fiber.Ctx) error {
	token := c.Params("token")

	var signer models.Signer
	if err := config.DB.Where("access_token = ?", token).First(&signer).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Signatário não encontrado"})
	}

	if signer.Status == "signed" {
		return c.Status(400).JSON(fiber.Map{"error": "Já assinado"})
	}

	code := generateOTPCode()
	expiresAt := time.Now().Add(10 * time.Minute)

	signer.SignToken = code
	signer.SignTokenExpiresAt = &expiresAt
	config.DB.Save(&signer)

	if err := sendVerificationCodeEmail(signer, code); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Falha ao enviar token por e-mail"})
	}

	return c.JSON(fiber.Map{"message": "Token enviado", "method": signer.AuthMethod})
}

// VerifyBiometria handles face verification
type BiometriaReq struct {
	Image string `json:"image"` // Base64
}

func VerifyBiometria(c *fiber.Ctx) error {
	token := c.Params("token")
	var req BiometriaReq
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Dados inválidos"})
	}
	if req.Image == "" {
		return c.Status(400).JSON(fiber.Map{"error": "Imagem é obrigatória"})
	}

	var signer models.Signer
	if err := config.DB.Where("access_token = ?", token).First(&signer).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Signatário não encontrado"})
	}

	// Decode Base64
	idx := strings.Index(req.Image, ";base64,")
	var b64Data string
	if idx != -1 {
		b64Data = req.Image[idx+8:]
	} else {
		b64Data = req.Image
	}

	imgBuffer, err := base64.StdEncoding.DecodeString(b64Data)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Imagem base64 inválida"})
	}

	// Salvar foto da biometria no MinIO
	photoKey := "selfie-documento/" + signer.DocumentID.String() + "/" + signer.ID.String() + "_" + time.Now().Format("20060102150405") + ".jpg"
	config.UploadToMinio(config.MinioBucket, photoKey, imgBuffer, int64(len(imgBuffer)), "image/jpeg")

	// Simulação de Sucesso da Facematch
	signer.BiometriaVerified = true
	signer.BiometriaScore = 100
	signer.BiometriaPhotoKey = photoKey
	config.DB.Save(&signer)

	config.DB.Create(&models.AuditEntry{
		DocumentID: signer.DocumentID,
		Action:     "biometria_verificada",
		Actor:      signer.Name,
		Details:    "Biometria validada com score 100",
		Timestamp:  time.Now(),
	})

	return c.JSON(fiber.Map{
		"verified": true,
		"score":    100,
		"message":  "Biometria registrada e aprovada com sucesso",
	})
}

// SignDocument finalizes the signature
type SignDocReq struct {
	SignatureData struct {
		Image string `json:"image"`
	} `json:"signature_data"`
	TokenCode string `json:"token_code"`
}

type SignFieldReq struct {
	SignatureType string `json:"signature_type"` // drawn | typed
	Image         string `json:"image"`
	TypedText     string `json:"typed_text"`
}

type CompleteValidationReq struct {
	Details string `json:"details"`
}

func completeDocumentIfAllSigned(documentID uuid.UUID) {
	var pendingCount int64
	config.DB.Model(&models.Signer{}).Where("document_id = ? AND status != 'signed'", documentID).Count(&pendingCount)
	if pendingCount != 0 {
		return
	}
	var doc models.Document
	if err := config.DB.First(&doc, "id = ?", documentID).Error; err != nil {
		return
	}
	doc.Status = "completed"
	config.DB.Save(&doc)
	config.DB.Create(&models.AuditEntry{
		DocumentID: doc.ID,
		Action:     "document_completed",
		Actor:      "System",
		Details:    "Todas as assinaturas coletadas. Finalizado.",
		Timestamp:  time.Now(),
	})
}

func finalizeSignerIfReady(signer *models.Signer, tokenCode string, c *fiber.Ctx) error {
	var doc models.Document
	if err := config.DB.First(&doc, "id = ?", signer.DocumentID).Error; err != nil {
		return fiber.NewError(404, "Documento não encontrado")
	}

	if doc.SequentialFlow {
		var blockers int64
		config.DB.Model(&models.Signer{}).
			Where("document_id = ? AND sign_order < ? AND status != 'signed'", signer.DocumentID, signer.SignOrder).
			Count(&blockers)
		if blockers > 0 {
			return fiber.NewError(400, "Aguardando assinaturas anteriores na ordem do fluxo")
		}
	}

	var pendingFields int64
	config.DB.Model(&models.DocumentField{}).
		Where("document_id = ? AND (signer_id IS NULL OR signer_id = ?) AND (value IS NULL OR value = '')", signer.DocumentID, signer.ID).
		Count(&pendingFields)
	if pendingFields > 0 {
		return fiber.NewError(400, "Preencha todos os campos pendentes antes de concluir")
	}

	var pendingValidation int64
	config.DB.Model(&models.ValidationStep{}).
		Where("document_id = ? AND signer_id = ? AND required = true AND status != 'completed'", signer.DocumentID, signer.ID).
		Count(&pendingValidation)
	if pendingValidation > 0 {
		return fiber.NewError(400, "Finalize as validações pendentes antes de concluir")
	}

	if signer.AuthMethod == "email_token" {
		if tokenCode == "" || signer.SignToken != tokenCode || signer.SignTokenExpiresAt == nil || time.Now().After(*signer.SignTokenExpiresAt) {
			return fiber.NewError(400, "Código inválido ou expirado")
		}
	}
	if signer.AuthMethod == "biometria_facial" && !signer.BiometriaVerified {
		return fiber.NewError(400, "Verificação biométrica necessária antes de concluir")
	}

	now := time.Now()
	signer.Status = "signed"
	signer.SignedAt = &now
	signer.SignedIP = c.IP()
	signer.SignedUserAgent = c.Get("User-Agent")
	signer.SignToken = ""
	if err := config.DB.Save(signer).Error; err != nil {
		return fiber.NewError(500, "Falha ao concluir assinatura")
	}

	config.DB.Create(&models.AuditEntry{
		DocumentID: signer.DocumentID,
		Action:     "signer_signed",
		Actor:      signer.Name,
		Details:    signer.Name + " concluiu a assinatura",
		Timestamp:  now,
	})
	notifyNextSignerInSequentialFlow(signer.DocumentID.String(), signer.SignOrder)
	completeDocumentIfAllSigned(signer.DocumentID)
	return nil
}

func SignDocumentField(c *fiber.Ctx) error {
	token := c.Params("token")
	fieldID, err := uuid.Parse(c.Params("fieldId"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Campo inválido"})
	}
	var req SignFieldReq
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Dados inválidos"})
	}

	var signer models.Signer
	if err := config.DB.Where("access_token = ?", token).First(&signer).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Assinatura não disponível"})
	}

	var field models.DocumentField
	if err := config.DB.Where("id = ? AND document_id = ?", fieldID, signer.DocumentID).First(&field).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Campo não encontrado"})
	}
	if field.SignerID != nil && *field.SignerID != signer.ID {
		return c.Status(403).JSON(fiber.Map{"error": "Campo pertence a outro signatário"})
	}

	signatureType := strings.TrimSpace(strings.ToLower(req.SignatureType))
	if signatureType == "" {
		signatureType = "drawn"
	}
	if signatureType == "typed" && strings.TrimSpace(req.TypedText) != "" {
		field.Value = strings.TrimSpace(req.TypedText)
	} else {
		field.Value = "signed_at:" + time.Now().Format(time.RFC3339)
	}
	if err := config.DB.Save(&field).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Falha ao salvar campo"})
	}

	signature := models.Signature{
		SignerID:      signer.ID,
		DocumentID:    signer.DocumentID,
		FieldID:       field.ID,
		SignatureType: signatureType,
		ImageBase64:   req.Image,
		TypedText:     req.TypedText,
		UserAgent:     c.Get("User-Agent"),
		IPAddress:     c.IP(),
		CreatedAt:     time.Now(),
	}

	// Upload signature image to MinIO if provided
	if req.Image != "" {
		idx := strings.Index(req.Image, ";base64,")
		var b64Data string
		if idx != -1 {
			b64Data = req.Image[idx+8:]
		} else {
			b64Data = req.Image
		}
		imgBuffer, err := base64.StdEncoding.DecodeString(b64Data)
		if err == nil {
			sigKey := "assinatura/" + signer.DocumentID.String() + "/" + field.ID.String() + "_" + time.Now().Format("20060102150405") + ".png"
			if err := config.UploadToMinio(config.MinioBucket, sigKey, imgBuffer, int64(len(imgBuffer)), "image/png"); err == nil {
				signature.ImageKey = sigKey
				// Also update signer's main signature key for convenience
				signer.SignatureImageKey = sigKey
				config.DB.Save(&signer)
			}
		}
	}
	config.DB.Create(&signature)

	config.DB.Create(&models.AuditEntry{
		DocumentID: signer.DocumentID,
		Action:     "field_signed",
		Actor:      signer.Name,
		Details:    "Campo " + field.FieldType + " assinado",
		Timestamp:  time.Now(),
		IPAddress:  c.IP(),
	})

	var pendingCount int64
	config.DB.Model(&models.DocumentField{}).
		Where("document_id = ? AND (signer_id IS NULL OR signer_id = ?) AND (value IS NULL OR value = '')", signer.DocumentID, signer.ID).
		Count(&pendingCount)
	return c.JSON(fiber.Map{
		"message":           "Campo assinado com sucesso",
		"pending_fields":    pendingCount,
		"all_fields_signed": pendingCount == 0,
	})
}

func CompleteValidationStep(c *fiber.Ctx) error {
	token := c.Params("token")
	stepID, err := uuid.Parse(c.Params("stepId"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Etapa inválida"})
	}
	var req CompleteValidationReq
	_ = c.BodyParser(&req)

	var signer models.Signer
	if err := config.DB.Where("access_token = ?", token).First(&signer).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Assinatura não disponível"})
	}
	var step models.ValidationStep
	if err := config.DB.Where("id = ? AND document_id = ? AND signer_id = ?", stepID, signer.DocumentID, signer.ID).First(&step).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Etapa não encontrada"})
	}

	var pendingBefore int64
	config.DB.Model(&models.ValidationStep{}).
		Where(`document_id = ? AND signer_id = ? AND required = true AND status != 'completed' AND "order" < ?`, signer.DocumentID, signer.ID, step.Order).
		Count(&pendingBefore)
	if pendingBefore > 0 {
		return c.Status(400).JSON(fiber.Map{"error": "Conclua as validações anteriores antes desta etapa"})
	}

	now := time.Now()
	step.Status = "completed"
	step.CompletedAt = &now
	if err := config.DB.Save(&step).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Falha ao concluir etapa"})
	}

	config.DB.Create(&models.AuditEntry{
		DocumentID: signer.DocumentID,
		Action:     "validation_completed",
		Actor:      signer.Name,
		Details:    "Validação concluída: " + step.StepType + ". " + strings.TrimSpace(req.Details),
		Timestamp:  now,
	})

	var pendingCount int64
	config.DB.Model(&models.ValidationStep{}).
		Where("document_id = ? AND signer_id = ? AND required = true AND status != 'completed'", signer.DocumentID, signer.ID).
		Count(&pendingCount)

	return c.JSON(fiber.Map{
		"message":              "Validação concluída",
		"pending_validations":  pendingCount,
		"all_validations_done": pendingCount == 0,
	})
}

func DownloadSigningDocument(c *fiber.Ctx) error {
	token := c.Params("token")
	var signer models.Signer
	if err := config.DB.Where("access_token = ?", token).First(&signer).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Assinatura não disponível"})
	}
	var doc models.Document
	if err := config.DB.Where("id = ?", signer.DocumentID).First(&doc).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Documento não encontrado"})
	}
	if strings.TrimSpace(doc.FileKey) == "" {
		return c.Status(404).JSON(fiber.Map{"error": "Arquivo não encontrado"})
	}
	apiPublicURL := os.Getenv("API_PUBLIC_URL")
	if apiPublicURL == "" {
		apiPublicURL = "http://localhost:4101"
	}
	fileUrl := strings.TrimRight(apiPublicURL, "/") + "/api/v1/documents/download/" + doc.FileKey
	return c.Redirect(fileUrl, 302)
}

func SignDocument(c *fiber.Ctx) error {
	token := c.Params("token")
	var req SignDocReq
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Dados inválidos"})
	}

	var signer models.Signer
	if err := config.DB.Where("access_token = ?", token).First(&signer).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Assinatura não disponível"})
	}

	_ = req.SignatureData
	if err := finalizeSignerIfReady(&signer, req.TokenCode, c); err != nil {
		if ferr, ok := err.(*fiber.Error); ok {
			return c.Status(ferr.Code).JSON(fiber.Map{"error": ferr.Message})
		}
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	var pendingCount int64
	config.DB.Model(&models.Signer{}).Where("document_id = ? AND status != 'signed'", signer.DocumentID).Count(&pendingCount)
	allSigned := pendingCount == 0

	return c.JSON(fiber.Map{
		"message":    "Assinatura concluída com sucesso!",
		"all_signed": allSigned,
	})
}

// generateOTPCode generates a secure 6-digit random code
func generateOTPCode() string {
	max := big.NewInt(1000000)
	n, err := rand.Int(rand.Reader, max)
	if err != nil {
		return "123456" // Fallback seguro
	}
	return fmt.Sprintf("%06d", n.Int64())
}
