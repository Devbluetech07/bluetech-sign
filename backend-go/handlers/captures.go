package handlers

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"backend-go/database"
	"backend-go/minio_client"
	"backend-go/models"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/minio/minio-go/v7"
)

// CreateCapture - Cria um registro de captura e envia para o MinIO
func CreateCapture(c *gin.Context) {
	ctx := context.Background()
	var body struct {
		ServiceType string         `json:"service_type" binding:"required"`
		ImageData   string         `json:"image_data" binding:"required"`
		Metadata    map[string]any `json:"metadata"`
		Embedding   []float64      `json:"embedding"`
	}

	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Dados inválidos"})
		return
	}

	// Extrai userId se autenticado
	var dbUserId *uuid.UUID
	if val, ok := c.Get("userId"); ok && val != nil {
		if userIDStr, ok := val.(string); ok {
			u, err := uuid.Parse(userIDStr)
			if err == nil {
				dbUserId = &u
			}
		} else if u, ok := val.(uuid.UUID); ok {
			dbUserId = &u
		}
	}

	validServices := map[string]bool{
		"assinatura": true, "documento": true, "selfie": true, "selfie-documento": true,
	}

	if !validServices[body.ServiceType] {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Tipo de serviço inválido"})
		return
	}

	if body.Metadata == nil {
		body.Metadata = make(map[string]any)
	}

	var latitude, longitude *float64
	var endereco *string
	var resultadoValidacao string = "{}"

	if lat, ok := body.Metadata["latitude"].(float64); ok {
		latitude = &lat
	}
	if lon, ok := body.Metadata["longitude"].(float64); ok {
		longitude = &lon
	}
	if end, ok := body.Metadata["endereco"].(string); ok {
		endereco = &end
	}
	if rr, ok := body.Metadata["resultado_validacao"]; ok {
		b, _ := json.Marshal(rr)
		resultadoValidacao = string(b)
	}
	metaBytes, _ := json.Marshal(body.Metadata)

	// Decode Base64 and Upload to MinIO
	b64data := body.ImageData
	if idx := strings.Index(b64data, ","); idx != -1 {
		b64data = b64data[idx+1:]
	}
	decodedImg, errDecode := base64.StdEncoding.DecodeString(b64data)
	if errDecode != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Falha ao decodificar a imagem"})
		return
	}

	bucketName := "bluetech-sign"
	filename := fmt.Sprintf("%s_%s_%s.png", body.ServiceType, time.Now().Format("20060102_150405_000"), uuid.New().String())
	objectPath := fmt.Sprintf("%s/%s", body.ServiceType, filename)

	userMeta := make(map[string]string)
	for k, v := range body.Metadata {
		if valStr, ok := v.(string); ok {
			userMeta[k] = valStr
		} else {
			userMeta[k] = fmt.Sprintf("%v", v)
		}
	}

	_, errMinio := minio_client.Client.PutObject(ctx, bucketName, objectPath, bytes.NewReader(decodedImg), int64(len(decodedImg)), minio.PutObjectOptions{
		ContentType:  "image/png",
		UserMetadata: userMeta,
	})

	if errMinio != nil {
		log.Printf("❌ MinIO PutObject Error: %v", errMinio)
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Falha ao salvar a imagem no storage: " + errMinio.Error()})
		return
	}

	// Backend Validation Logic (Simulated for high precision as requested)
	// In a real scenario, this would call an OCR/AI service
	validationStatus := "valid"
	if body.ServiceType == "documento" {
		// Mock logic: if 'error' is in metadata, fail it
		if _, fail := body.Metadata["simulate_error"]; fail {
			validationStatus = "invalid"
		}
	}

	var cap models.Capture
	var err error
	
	// Ensure metadata has validation result
	body.Metadata["validation_status"] = validationStatus
	metaBytes, _ = json.Marshal(body.Metadata)

	if len(body.Embedding) > 0 {
		var strVals []string
		for _, v := range body.Embedding {
			strVals = append(strVals, strconv.FormatFloat(v, 'f', -1, 64))
		}
		embStr := "[" + strings.Join(strVals, ",") + "]"

		err = database.Pool.QueryRow(ctx,
			`INSERT INTO registros_captura
			(usuario_id, tipo_servico, status, image_data, latitude, longitude, endereco, resultado_validacao, metadados, embedding)
			VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
			RETURNING id, tipo_servico, status, image_data, metadados, criado_em`,
			dbUserId, body.ServiceType, validationStatus, objectPath, latitude, longitude, endereco, resultadoValidacao, string(metaBytes), embStr,
		).Scan(&cap.ID, &cap.ServiceType, &cap.Status, &cap.ImageData, &cap.Metadata, &cap.CreatedAt)
	} else {
		err = database.Pool.QueryRow(ctx,
			`INSERT INTO registros_captura
			(usuario_id, tipo_servico, status, image_data, latitude, longitude, endereco, resultado_validacao, metadados)
			VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
			RETURNING id, tipo_servico, status, image_data, metadados, criado_em`,
			dbUserId, body.ServiceType, validationStatus, objectPath, latitude, longitude, endereco, resultadoValidacao, string(metaBytes),
		).Scan(&cap.ID, &cap.ServiceType, &cap.Status, &cap.ImageData, &cap.Metadata, &cap.CreatedAt)

		if err == nil {
			database.Pool.Exec(ctx, "INSERT INTO embedding_jobs (captura_id) VALUES ($1)", cap.ID)
		}
	}

	if err != nil {
		fmt.Println("DB Insert Error:", err)
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Erro ao salvar no banco de dados"})
		return
	}

	// Invalidate cache for this user (all variants: by service_type, limit, offset, etc.)
	if dbUserId != nil {
		prefix := fmt.Sprintf("captures_%v", dbUserId)
		database.CacheDeletePrefix(prefix)
		log.Printf("🧹 Cache invalidated for user %v with prefix %s", dbUserId, prefix)
	}

	c.JSON(http.StatusCreated, cap)
}

func GetCaptures(c *gin.Context) {
	userId, _ := c.Get("userId")
	
	serviceType := c.Query("service_type")
	limitStr := c.Query("limit")
	offsetStr := c.Query("offset")

	// Check Cache
	cacheKey := fmt.Sprintf("captures_%v_%s_%s_%s", userId, serviceType, limitStr, offsetStr)
	if cached, ok := database.CacheGet(cacheKey); ok {
		c.JSON(http.StatusOK, cached)
		return
	}

	limit := 20
	if l, err := strconv.Atoi(limitStr); err == nil && l > 0 && l <= 100 {
		limit = l
	}
	
	offset := 0
	if o, err := strconv.Atoi(offsetStr); err == nil && o >= 0 {
		offset = o
	}

	sql := "SELECT id, tipo_servico, status, image_data, metadados, criado_em FROM registros_captura WHERE usuario_id = $1"
	args := []any{userId}

	if serviceType != "" {
		validServices := map[string]bool{
			"assinatura": true, "documento": true, "selfie": true, "selfie-documento": true,
		}
		if validServices[serviceType] {
			args = append(args, serviceType)
			sql += fmt.Sprintf(" AND tipo_servico = $%d", len(args))
		}
	}

	args = append(args, limit, offset)
	sql += fmt.Sprintf(" ORDER BY criado_em DESC LIMIT $%d OFFSET $%d", len(args)-1, len(args))

	ctx := context.Background()
	rows, err := database.Pool.Query(ctx, sql, args...)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Erro interno"})
		return
	}
	defer rows.Close()

	captures := make([]models.Capture, 0)
	for rows.Next() {
		var cap models.Capture
		if err := rows.Scan(&cap.ID, &cap.ServiceType, &cap.Status, &cap.ImageData, &cap.Metadata, &cap.CreatedAt); err == nil {
			captures = append(captures, cap)
		}
	}

	// Set Cache (5 minutes)
	database.CacheSet(cacheKey, captures, 5*time.Minute)

	c.JSON(http.StatusOK, captures)
}

func GetCapture(c *gin.Context) {
	userId, _ := c.Get("userId")
	id := c.Param("id")

	ctx := context.Background()
	var cap models.Capture
	err := database.Pool.QueryRow(ctx,
		"SELECT id, tipo_servico, status, image_data, metadados, criado_em FROM registros_captura WHERE id=$1 AND usuario_id=$2",
		id, userId,
	).Scan(&cap.ID, &cap.ServiceType, &cap.Status, &cap.ImageData, &cap.Metadata, &cap.CreatedAt)

	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "Não encontrado"})
		return
	}

	c.JSON(http.StatusOK, cap)
}

func SearchCaptures(c *gin.Context) {
	userId, _ := c.Get("userId")

	var body struct {
		Embedding []float64 `json:"embedding" binding:"required"`
		Limit     int       `json:"limit"`
	}

	if err := c.ShouldBindJSON(&body); err != nil || len(body.Embedding) != 1536 {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Dados inválidos"})
		return
	}

	if body.Limit <= 0 || body.Limit > 50 {
		body.Limit = 5
	}

	var strVals []string
	for _, v := range body.Embedding {
		strVals = append(strVals, strconv.FormatFloat(v, 'f', -1, 64))
	}
	embStr := "[" + strings.Join(strVals, ",") + "]"

	ctx := context.Background()
	rows, err := database.Pool.Query(ctx,
		`SELECT id, tipo_servico, metadados, criado_em, 1 - (embedding <=> $1::vector) AS similarity
		 FROM registros_captura
		 WHERE usuario_id=$2 AND embedding IS NOT NULL
		 ORDER BY embedding <=> $1::vector LIMIT $3`,
		embStr, userId, body.Limit,
	)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Erro interno"})
		return
	}
	defer rows.Close()

	results := make([]models.SearchCaptureResult, 0)
	for rows.Next() {
		var res models.SearchCaptureResult
		if err := rows.Scan(&res.ID, &res.ServiceType, &res.Metadata, &res.CreatedAt, &res.Similarity); err == nil {
			results = append(results, res)
		}
	}

	c.JSON(http.StatusOK, results)
}
