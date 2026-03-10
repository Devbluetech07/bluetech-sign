package controllers

import (
	"context"
	"io"
	"log"

	"github.com/gofiber/fiber/v2"
	"github.com/gustavogomes000/singproof-go/config"
	"github.com/minio/minio-go/v7"
)

func UploadDocumentFile(c *fiber.Ctx) error {
	fileHeader, err := c.FormFile("file")
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Faltando arquivo 'file'"})
	}

	file, err := fileHeader.Open()
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Erro ao ler arquivo"})
	}
	defer file.Close()

	// Cria o nome do objeto (você associaria ao uuid do documento criado)
	objectName := c.FormValue("document_id") + "-" + fileHeader.Filename

	ctx := context.Background()
	info, err := config.MinioClient.PutObject(ctx, config.MinioBucket, objectName, file, fileHeader.Size, minio.PutObjectOptions{ContentType: "application/pdf"})
	if err != nil {
		log.Println("Erro upload MinIO:", err)
		return c.Status(500).JSON(fiber.Map{"error": "Falha no upload"})
	}

	return c.JSON(fiber.Map{
		"message":   "Upload completo",
		"file_name": info.Key,
		"size":      info.Size,
	})
}

func DownloadDocumentFile(c *fiber.Ctx) error {
	objectName := c.Params("filename")

	ctx := context.Background()
	obj, err := config.MinioClient.GetObject(ctx, config.MinioBucket, config.ResolveObjectName(objectName), minio.GetObjectOptions{})
	if err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Arquivo não encontrado"})
	}
	defer obj.Close()

	// Lê tudo para a memória (Ideal fazer stream para grandes arquivos)
	data, err := io.ReadAll(obj)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Erro ao ler arquivo do S3"})
	}

	c.Set("Content-Type", "application/pdf")
	return c.Send(data)
}
