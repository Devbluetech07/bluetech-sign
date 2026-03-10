package handlers

import (
	"context"
	"crypto/sha256"
	"encoding/binary"
	"fmt"
	"log"
	"math"
	"strings"
	"time"

	"backend-go/database"
)

const embeddingDims = 1536

func StartEmbeddingWorker() {
	go func() {
		ticker := time.NewTicker(3 * time.Second)
		defer ticker.Stop()

		for range ticker.C {
			for i := 0; i < 20; i++ {
				processed, err := processOneEmbeddingJob(context.Background())
				if err != nil {
					log.Printf("⚠️ embedding worker error: %v", err)
					break
				}
				if !processed {
					break
				}
			}
		}
	}()
}

func processOneEmbeddingJob(ctx context.Context) (bool, error) {
	var jobID int
	var captureID string
	var serviceType string
	var imageData string
	var metadata string

	err := database.Pool.QueryRow(ctx,
		`WITH next_job AS (
			SELECT ej.id, ej.captura_id
			FROM embedding_jobs ej
			WHERE ej.status = 'pending'
			ORDER BY ej.id
			FOR UPDATE SKIP LOCKED
			LIMIT 1
		)
		UPDATE embedding_jobs ej
		SET status = 'processing'
		FROM next_job nj
		JOIN registros_captura rc ON rc.id = nj.captura_id
		WHERE ej.id = nj.id
		RETURNING ej.id, rc.id::text, rc.tipo_servico, COALESCE(rc.image_data, ''), COALESCE(rc.metadados::text, '{}')`,
	).Scan(&jobID, &captureID, &serviceType, &imageData, &metadata)
	if err != nil {
		// no pending jobs
		return false, nil
	}

	seed := serviceType + "|" + imageData + "|" + metadata
	vector := deterministicEmbedding(seed, embeddingDims)
	vectorLiteral := toPgVectorLiteral(vector)

	_, err = database.Pool.Exec(ctx,
		"UPDATE registros_captura SET embedding = $1::vector WHERE id = $2",
		vectorLiteral, captureID,
	)
	if err != nil {
		_, _ = database.Pool.Exec(ctx, "UPDATE embedding_jobs SET status = 'failed' WHERE id = $1", jobID)
		return true, err
	}

	_, err = database.Pool.Exec(ctx, "UPDATE embedding_jobs SET status = 'done' WHERE id = $1", jobID)
	if err != nil {
		return true, err
	}

	return true, nil
}

func deterministicEmbedding(seed string, dims int) []float64 {
	out := make([]float64, dims)
	for i := 0; i < dims; i++ {
		h := sha256.Sum256([]byte(fmt.Sprintf("%s#%d", seed, i)))
		u := binary.BigEndian.Uint64(h[:8])
		v := (float64(u)/float64(^uint64(0)))*2 - 1 // [-1,1]
		out[i] = v
	}

	// L2 normalize for cosine similarity.
	var norm float64
	for _, v := range out {
		norm += v * v
	}
	norm = math.Sqrt(norm)
	if norm == 0 {
		return out
	}
	for i := range out {
		out[i] = out[i] / norm
	}
	return out
}

func toPgVectorLiteral(vec []float64) string {
	parts := make([]string, 0, len(vec))
	for _, v := range vec {
		parts = append(parts, fmt.Sprintf("%.8f", v))
	}
	return "[" + strings.Join(parts, ",") + "]"
}

