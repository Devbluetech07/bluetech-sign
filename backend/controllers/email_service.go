package controllers

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/gustavogomes000/singproof-go/config"
	"github.com/gustavogomes000/singproof-go/models"
)

func frontendURL() string {
	base := strings.TrimSpace(os.Getenv("FRONTEND_URL"))
	if base == "" {
		base = "http://localhost:4100"
	}
	return strings.TrimRight(base, "/")
}

func emailFromAddress() string {
	from := strings.TrimSpace(os.Getenv("EMAIL_FROM"))
	if from == "" {
		from = "SignProof <no-reply@signproof.app>"
	}
	return from
}

func sendEmailViaResend(to, subject, htmlBody string) error {
	apiKey := strings.TrimSpace(os.Getenv("RESEND_API_KEY"))
	if apiKey == "" {
		return errors.New("RESEND_API_KEY não configurada")
	}
	if strings.TrimSpace(to) == "" {
		return errors.New("destinatário vazio")
	}

	payload := map[string]any{
		"from":    emailFromAddress(),
		"to":      []string{to},
		"subject": subject,
		"html":    htmlBody,
	}
	body, _ := json.Marshal(payload)

	req, err := http.NewRequest("POST", "https://api.resend.com/emails", bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+apiKey)
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 15 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		respBody, _ := io.ReadAll(resp.Body)
		log.Printf("Erro Resend (Status %d): %s", resp.StatusCode, string(respBody))
		return fmt.Errorf("resend respondeu com status %d: %s", resp.StatusCode, string(respBody))
	}
	return nil
}

func sendSigningInviteEmail(doc models.Document, signer models.Signer, reason string) error {
	link := frontendURL() + "/sign/" + signer.AccessToken.String()
	subject := fmt.Sprintf("Assinatura pendente: %s", doc.Name)
	html := fmt.Sprintf(`
		<div style="font-family: Arial, sans-serif; line-height:1.6;">
			<h2>Você recebeu um documento para assinar</h2>
			<p><strong>Documento:</strong> %s</p>
			<p><strong>Signatário:</strong> %s</p>
			<p>%s</p>
			<p>
				<a href="%s" style="display:inline-block;padding:10px 16px;background:#00C4CC;color:#000;text-decoration:none;border-radius:8px;font-weight:bold;">
					Abrir para assinar
				</a>
			</p>
			<p>Ou copie este link: %s</p>
			<p>SignProof</p>
		</div>
	`, doc.Name, signer.Name, reason, link, link)
	return sendEmailViaResend(signer.Email, subject, html)
}

func sendVerificationCodeEmail(signer models.Signer, code string) error {
	subject := "Seu código de verificação - SignProof"
	html := fmt.Sprintf(`
		<div style="font-family: Arial, sans-serif; line-height:1.6;">
			<h2>Código de verificação</h2>
			<p>Olá, %s.</p>
			<p>Use o código abaixo para concluir a assinatura:</p>
			<div style="font-size:28px;font-weight:bold;letter-spacing:4px;">%s</div>
			<p>Este código expira em 10 minutos.</p>
			<p>Se você não solicitou este código, ignore este e-mail.</p>
		</div>
	`, signer.Name, code)
	return sendEmailViaResend(signer.Email, subject, html)
}

func notifyNextSignerInSequentialFlow(documentID string, signedOrder int) {
	var doc models.Document
	if err := config.DB.Preload("Signers").First(&doc, "id = ?", documentID).Error; err != nil {
		return
	}
	if !doc.SequentialFlow {
		return
	}

	var nextSigner models.Signer
	if err := config.DB.
		Where("document_id = ? AND sign_order = ? AND status != 'signed'", doc.ID, signedOrder+1).
		Order("created_at asc").
		First(&nextSigner).Error; err != nil {
		return
	}

	now := time.Now()
	nextSigner.Status = "sent"
	nextSigner.NotifiedAt = &now
	_ = config.DB.Save(&nextSigner).Error
	_ = sendSigningInviteEmail(doc, nextSigner, "Agora é a sua vez na ordem sequencial.")
}
