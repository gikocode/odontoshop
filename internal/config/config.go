package config

import (
	"fmt"
	"os"
	"strconv"

	"github.com/joho/godotenv"
)

type Config struct {
	Server   ServerConfig
	Database DatabaseConfig
	Redis    RedisConfig
	RabbitMQ RabbitMQConfig
	Security SecurityConfig
}

type ServerConfig struct {
	Port               string
	GinMode            string
	Env                string
	CorsAllowedOrigins string
}

type DatabaseConfig struct {
	Host     string
	Port     string
	User     string
	Password string
	Name     string
	SSLMode  string
	URL      string // URL completa construida
}

type RedisConfig struct {
	Host     string
	Port     string
	Password string
	DB       int
	URL      string // URL completa
}

type RabbitMQConfig struct {
	Host     string
	Port     string
	User     string
	Password string
	Vhost    string
	URL      string // URL completa
}

type SecurityConfig struct {
	JWTSecret     string
	JWTExpiration string
	EncryptionKey string
}

// Load carga la configuración desde variables de entorno
func Load() *Config {
	// Intentar cargar .env (solo si existe, no falla si no está)
	_ = godotenv.Load()
	return &Config{
		Server: ServerConfig{
			Port:               getEnv("PORT", "3001"),
			GinMode:            getEnv("GIN_MODE", "debug"),
			Env:                getEnv("ENV", "development"),
			CorsAllowedOrigins: getEnv("CORS_ALLOWED_ORIGINS", "http://localhost:3000"),
		},
		Database: DatabaseConfig{
			Host:     getEnv("DB_HOST", "localhost"),
			Port:     getEnv("DB_PORT", "5432"),
			User:     getEnv("DB_USER", "postgres"),
			Password: getEnvRequired("DB_PASSWORD"),
			Name:     getEnv("DB_NAME", "odontoshop"),
			SSLMode:  getEnv("DB_SSLMODE", "disable"),
			URL:      buildDatabaseURL(),
		},
		Redis: RedisConfig{
			Host:     getEnv("REDIS_HOST", "localhost"),
			Port:     getEnv("REDIS_PORT", "6379"),
			Password: getEnv("REDIS_PASSWORD", ""),
			DB:       getEnvAsInt("REDIS_DB", 0),
			URL:      buildRedisURL(),
		},
		RabbitMQ: RabbitMQConfig{
			Host:     getEnv("RABBITMQ_HOST", "localhost"),
			Port:     getEnv("RABBITMQ_PORT", "5672"),
			User:     getEnv("RABBITMQ_USER", "guest"),
			Password: getEnv("RABBITMQ_PASSWORD", "guest"),
			Vhost:    getEnv("RABBITMQ_VHOST", "/"),
			URL:      buildRabbitMQURL(),
		},
		Security: SecurityConfig{
			JWTSecret:     getEnvRequired("JWT_SECRET"),
			JWTExpiration: getEnv("JWT_EXPIRATION", "24h"),
			EncryptionKey: getEnvRequired("ENCRYPTION_KEY"),
		},
	}
}

// getEnv obtiene una variable de entorno con fallback
func getEnv(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}

// getEnvRequired obtiene una variable OBLIGATORIA (falla si no existe)
func getEnvRequired(key string) string {
	value := os.Getenv(key)
	if value == "" {
		panic(fmt.Sprintf("Variable de entorno requerida no encontrada: %s", key))
	}
	return value
}

// getEnvAsInt convierte a entero con fallback
func getEnvAsInt(key string, fallback int) int {
	valueStr := os.Getenv(key)
	if valueStr == "" {
		return fallback
	}
	value, err := strconv.Atoi(valueStr)
	if err != nil {
		return fallback
	}
	return value
}

// buildDatabaseURL construye la URL de PostgreSQL
func buildDatabaseURL() string {
	// Si ya existe DATABASE_URL, usarla
	if url := os.Getenv("DATABASE_URL"); url != "" {
		return url
	}

	// Sino, construirla
	return fmt.Sprintf(
		"postgres://%s:%s@%s:%s/%s?sslmode=%s",
		getEnv("DB_USER", "postgres"),
		getEnvRequired("DB_PASSWORD"),
		getEnv("DB_HOST", "localhost"),
		getEnv("DB_PORT", "5432"),
		getEnv("DB_NAME", "odontoshop"),
		getEnv("DB_SSLMODE", "disable"),
	)
}

// buildRedisURL construye la URL de Redis
func buildRedisURL() string {
	if url := os.Getenv("REDIS_URL"); url != "" {
		return url
	}

	password := getEnv("REDIS_PASSWORD", "")
	host := getEnv("REDIS_HOST", "localhost")
	port := getEnv("REDIS_PORT", "6379")
	db := getEnv("REDIS_DB", "0")

	if password != "" {
		return fmt.Sprintf("redis://:%s@%s:%s/%s", password, host, port, db)
	}
	return fmt.Sprintf("redis://%s:%s/%s", host, port, db)
}

// buildRabbitMQURL construye la URL de RabbitMQ
func buildRabbitMQURL() string {
	if url := os.Getenv("RABBITMQ_URL"); url != "" {
		return url
	}

	return fmt.Sprintf(
		"amqp://%s:%s@%s:%s%s",
		getEnv("RABBITMQ_USER", "guest"),
		getEnv("RABBITMQ_PASSWORD", "guest"),
		getEnv("RABBITMQ_HOST", "localhost"),
		getEnv("RABBITMQ_PORT", "5672"),
		getEnv("RABBITMQ_VHOST", "/"),
	)
}
