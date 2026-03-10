package database

import (
	"context"
	"fmt"
	"log"
	"os"
	"sync"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

var Pool *pgxpool.Pool

func ConnectDB() error {
	host := os.Getenv("DB_HOST")
	if host == "" {
		host = "postgres"
	}
	port := os.Getenv("DB_PORT")
	if port == "" {
		port = "5432"
	}
	dbName := os.Getenv("DB_NAME")
	if dbName == "" {
		dbName = "valeris"
	}
	user := os.Getenv("DB_USER")
	if user == "" {
		user = "valeris"
	}
	password := os.Getenv("DB_PASSWORD")
	if password == "" {
		password = "valerispass"
	}

	connStr := fmt.Sprintf("postgres://%s:%s@%s:%s/%s?sslmode=disable", user, password, host, port, dbName)

	config, err := pgxpool.ParseConfig(connStr)
	if err != nil {
		return err
	}

	config.MaxConns = 20

	Pool, err = pgxpool.NewWithConfig(context.Background(), config)
	if err != nil {
		return err
	}

	err = Pool.Ping(context.Background())
	if err != nil {
		return err
	}

	log.Println("✅ Database connected")
	return nil
}

// Simple in-memory cache for speed
var (
	cache   = make(map[string]interface{})
	cacheMu sync.RWMutex
)

func CacheSet(key string, value interface{}, duration time.Duration) {
	cacheMu.Lock()
	cache[key] = value
	cacheMu.Unlock()

	if duration > 0 {
		go func() {
			time.Sleep(duration)
			cacheMu.Lock()
			delete(cache, key)
			cacheMu.Unlock()
		}()
	}
}

func CacheGet(key string) (interface{}, bool) {
	cacheMu.RLock()
	defer cacheMu.RUnlock()
	val, ok := cache[key]
	return val, ok
}

// CacheDeletePrefix deletes all keys that start with the given prefix
func CacheDeletePrefix(prefix string) {
	cacheMu.Lock()
	defer cacheMu.Unlock()
	for k := range cache {
		if len(k) >= len(prefix) && k[:len(prefix)] == prefix {
			delete(cache, k)
		}
	}
}
