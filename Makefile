include .env
export

# Variables
BINARY_NAME=api-server
MAIN_PATH=cmd/api/main.go
MIGRATIONS_PATH=migrations

.PHONY: all build run test migrate-up migrate-down seed dev

## --- ESENCIALES ---

build:
	@echo "Compilando binario..."
	@go build -o bin/${BINARY_NAME} ${MAIN_PATH}

run:
	@go run ${MAIN_PATH}

test:
	@go test -v ./internal/...

test-integration:
	@go test -v ./internal/infrastructure/persistence/...

## --- BASE DE DATOS & MIGRACIONES ---

migrate-up:
	@echo "Ejecutando migraciones..."
	@migrate -path $(MIGRATIONS_PATH) -database "$(DATABASE_URL)" up

migrate-down:
	@echo "Revirtiendo migraciones..."
	@migrate -path $(MIGRATIONS_PATH) -database "$(DATABASE_URL)" down

seed:
	@echo "Insertando datos de prueba..."
	@psql $(DATABASE_URL) -f scripts/seed.sql

db-reset: migrate-down migrate-up seed

## --- CALIDAD DE CÓDIGO ---

lint:
	@golangci-lint run

fmt:
	@go fmt ./...

vet:
	@go vet ./...

## --- DOCKER ---

docker-up:
	@docker-compose up -d

docker-down:
	@docker-compose down

## --- COMANDO MAESTRO ---

dev: docker-up migrate-up seed run