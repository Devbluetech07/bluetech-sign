package config

import (
	"bytes"
	"context"
	"log"
	"os"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

var MinioClient *minio.Client
var MinioBucket = "bluetech-sign"
var MinioProjectFolder = ""

func UploadToMinio(bucketName, objectName string, data []byte, size int64, contentType string) error {
	ctx := context.Background()

	// Prepend project folder if set
	finalPath := ResolveObjectName(objectName)
	exists, err := MinioClient.BucketExists(ctx, bucketName)
	if err == nil && !exists {
		MinioClient.MakeBucket(ctx, bucketName, minio.MakeBucketOptions{})
	}
	reader := bytes.NewReader(data)
	_, err = MinioClient.PutObject(ctx, bucketName, finalPath, reader, size, minio.PutObjectOptions{
		ContentType: contentType,
	})
	return err
}

func ResolveObjectName(objectName string) string {
	if MinioProjectFolder == "" {
		return objectName
	}
	return MinioProjectFolder + "/" + objectName
}

func ConnectMinio() {
	endpoint := os.Getenv("MINIO_ENDPOINT")
	if endpoint == "" {
		endpoint = "localhost:29102"
	}
	accessKeyID := os.Getenv("MINIO_ACCESS_KEY")
	if accessKeyID == "" {
		accessKeyID = "minioadmin"
	}
	secretAccessKey := os.Getenv("MINIO_SECRET_KEY")
	if secretAccessKey == "" {
		secretAccessKey = "minioadmin123"
	}
	useSSL := os.Getenv("MINIO_USE_SSL") == "true"

	client, err := minio.New(endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(accessKeyID, secretAccessKey, ""),
		Secure: useSSL,
	})
	if err != nil {
		log.Fatal("Falha ao inicializar o cliente do MinIO: ", err)
	}

	bucket := os.Getenv("MINIO_BUCKET")
	if bucket != "" {
		MinioBucket = bucket
	}

	MinioProjectFolder = os.Getenv("MINIO_PROJECT_FOLDER")

	MinioClient = client
	log.Println("Conectado ao MinIO com sucesso no endpoint:", endpoint, "bucket:", MinioBucket, "folder:", MinioProjectFolder)
}
