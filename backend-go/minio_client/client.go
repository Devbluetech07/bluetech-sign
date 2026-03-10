package minio_client

import (
	"context"
	"log"
	"os"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

var Client *minio.Client

func InitMinio() {
	endpoint := os.Getenv("MINIO_ENDPOINT")
	if endpoint == "" {
		endpoint = "minio:9000" // default internal docker network
	}
	accessKeyID := os.Getenv("MINIO_ROOT_USER")
	if accessKeyID == "" {
		accessKeyID = "minioadmin"
	}
	secretAccessKey := os.Getenv("MINIO_ROOT_PASSWORD")
	if secretAccessKey == "" {
		secretAccessKey = "minioadmin"
	}
	useSSL := os.Getenv("MINIO_USE_SSL") == "true"

	var err error
	Client, err = minio.New(endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(accessKeyID, secretAccessKey, ""),
		Secure: useSSL,
	})

	if err != nil {
		log.Fatalf("❌ Failed to initialize MinIO client: %v", err)
	}

	// Ensure bucket exists
	bucketName := "bluetech-sign"
	ctx := context.Background()
	exists, err := Client.BucketExists(ctx, bucketName)
	if err == nil && !exists {
		err = Client.MakeBucket(ctx, bucketName, minio.MakeBucketOptions{})
		if err != nil {
			log.Printf("⚠️ Warning: Could not create bucket %s: %v", bucketName, err)
		} else {
			log.Printf("📦 Bucket %s created successfully", bucketName)
		}
	}

	log.Println("✅ MinIO client initialized successfully")
}
