# setup-odontoshop.ps1
# Script para crear estructura del proyecto en Windows

Write-Host "🚀 Creando estructura del proyecto OdontoShop..." -ForegroundColor Green

# Crear directorio raíz
New-Item -ItemType Directory -Force -Path "odontoshop" | Out-Null
Set-Location "odontoshop"

# ============================================
# ESTRUCTURA BASE
# ============================================

# Crear todos los directorios
$directories = @(
    "cmd\api",
    "internal\modules\admin\controllers",
    "internal\modules\admin\services",
    "internal\modules\admin\routes",
    "internal\modules\pos\controllers",
    "internal\modules\pos\services",
    "internal\modules\pos\routes",
    "internal\modules\ecommerce\controllers",
    "internal\modules\ecommerce\services",
    "internal\modules\ecommerce\routes",
    "internal\modules\auth\controllers",
    "internal\modules\auth\services",
    "internal\modules\auth\routes",
    "internal\modules\auth\middleware",
    "internal\core\domain\product",
    "internal\core\domain\inventory",
    "internal\core\domain\customer",
    "internal\core\domain\sale",
    "internal\core\events\handlers",
    "internal\core\events\publishers",
    "internal\core\database\migrations",
    "internal\core\database\seeds",
    "internal\infrastructure\cache",
    "internal\infrastructure\messaging",
    "internal\infrastructure\storage",
    "internal\shared\guards",
    "internal\shared\middleware",
    "internal\shared\utils",
    "internal\config",
    "pkg\common\types",
    "pkg\common\constants",
    "pkg\common\validators",
    "web\admin",
    "web\pos",
    "web\ecommerce",
    "scripts",
    "configs",
    "deployments\docker"
)

foreach ($dir in $directories) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}

Write-Host "✅ Directorios creados" -ForegroundColor Cyan

# ============================================
# ARCHIVOS RAÍZ
# ============================================

# go.mod
@"
module github.com/GikoCode/odontoshop

go 1.21

require (
	github.com/gin-gonic/gin v1.9.1
	github.com/lib/pq v1.10.9
	github.com/redis/go-redis/v9 v9.3.0
	github.com/streadway/amqp v1.1.0
	github.com/golang-jwt/jwt/v5 v5.2.0
	github.com/google/uuid v1.5.0
	gorm.io/gorm v1.25.5
	gorm.io/driver/postgres v1.5.4
)
"@ | Out-File -FilePath "go.mod" -Encoding utf8

# README.md
@"
# OdontoShop - Sistema de Gestión Dental

Monolito modular en Go con:
- Admin Panel
- Sistema POS
- E-commerce
- Inventario unificado
"@ | Out-File -FilePath "README.md" -Encoding utf8

# .gitignore
@"
# Binaries
*.exe
*.exe~
*.dll
*.so
*.dylib
bin/
dist/

# Test binary
*.test

# Output
*.out

# Vendor
vendor/

# Go workspace
go.work

# Environment
.env
.env.local

# IDE
.idea/
.vscode/
*.swp

# OS
.DS_Store
Thumbs.db
"@ | Out-File -FilePath ".gitignore" -Encoding utf8

# .env.example
@"
# Database
DB_HOST=localhost
DB_PORT=5432
DB_USER=admin
DB_PASSWORD=your_password
DB_NAME=odontoshop

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379

# RabbitMQ
RABBITMQ_HOST=localhost
RABBITMQ_PORT=5672
RABBITMQ_USER=admin
RABBITMQ_PASSWORD=your_password

# JWT
JWT_SECRET=your_jwt_secret_key

# Server
PORT=3001
"@ | Out-File -FilePath ".env.example" -Encoding utf8

# ============================================
# CMD
# ============================================

@"
package main

import (
	"log"
	"github.com/GikoCode/odontoshop/internal/config"
	"github.com/GikoCode/odontoshop/internal/modules/admin"
	"github.com/GikoCode/odontoshop/internal/modules/pos"
	"github.com/GikoCode/odontoshop/internal/modules/ecommerce"
	"github.com/GikoCode/odontoshop/internal/modules/auth"
	"github.com/GikoCode/odontoshop/internal/core/database"
	"github.com/GikoCode/odontoshop/internal/infrastructure/cache"
	"github.com/GikoCode/odontoshop/internal/infrastructure/messaging"
)

func main() {
	log.Println("Starting OdontoShop API...")
}
"@ | Out-File -FilePath "cmd\api\main.go" -Encoding utf8

# ============================================
# CONFIG
# ============================================

@"
package config

import (
	"os"
)
"@ | Out-File -FilePath "internal\config\config.go" -Encoding utf8

@"
package config

import (
	"fmt"
)
"@ | Out-File -FilePath "internal\config\database.go" -Encoding utf8

"package config" | Out-File -FilePath "internal\config\redis.go" -Encoding utf8
"package config" | Out-File -FilePath "internal\config\rabbitmq.go" -Encoding utf8

# ============================================
# MODULES - ADMIN
# ============================================

@"
package admin

import (
	"github.com/GikoCode/odontoshop/internal/modules/admin/controllers"
	"github.com/GikoCode/odontoshop/internal/modules/admin/services"
	"github.com/GikoCode/odontoshop/internal/modules/admin/routes"
)
"@ | Out-File -FilePath "internal\modules\admin\module.go" -Encoding utf8

@"
package controllers

import (
	"github.com/gin-gonic/gin"
	"github.com/GikoCode/odontoshop/internal/modules/admin/services"
)
"@ | Out-File -FilePath "internal\modules\admin\controllers\dashboard.go" -Encoding utf8

@"
package services

import (
	"github.com/GikoCode/odontoshop/internal/core/domain/product"
	"github.com/GikoCode/odontoshop/internal/core/domain/sale"
)
"@ | Out-File -FilePath "internal\modules\admin\services\dashboard.go" -Encoding utf8

@"
package routes

import (
	"github.com/gin-gonic/gin"
	"github.com/GikoCode/odontoshop/internal/modules/admin/controllers"
)
"@ | Out-File -FilePath "internal\modules\admin\routes\routes.go" -Encoding utf8

# ============================================
# MODULES - POS
# ============================================

@"
package pos

import (
	"github.com/GikoCode/odontoshop/internal/modules/pos/controllers"
	"github.com/GikoCode/odontoshop/internal/modules/pos/services"
	"github.com/GikoCode/odontoshop/internal/modules/pos/routes"
)
"@ | Out-File -FilePath "internal\modules\pos\module.go" -Encoding utf8

@"
package controllers

import (
	"github.com/gin-gonic/gin"
	"github.com/GikoCode/odontoshop/internal/modules/pos/services"
)
"@ | Out-File -FilePath "internal\modules\pos\controllers\sale.go" -Encoding utf8

@"
package controllers

import (
	"github.com/gin-gonic/gin"
	"github.com/GikoCode/odontoshop/internal/modules/pos/services"
)
"@ | Out-File -FilePath "internal\modules\pos\controllers\cash_register.go" -Encoding utf8

@"
package controllers

import (
	"github.com/gin-gonic/gin"
)
"@ | Out-File -FilePath "internal\modules\pos\controllers\shift.go" -Encoding utf8

@"
package services

import (
	"github.com/GikoCode/odontoshop/internal/core/domain/inventory"
	"github.com/GikoCode/odontoshop/internal/core/domain/sale"
	"github.com/GikoCode/odontoshop/internal/core/events"
)
"@ | Out-File -FilePath "internal\modules\pos\services\pos_sale.go" -Encoding utf8

@"
package services

import (
	"github.com/GikoCode/odontoshop/internal/core/domain/sale"
)
"@ | Out-File -FilePath "internal\modules\pos\services\cash_register.go" -Encoding utf8

@"
package routes

import (
	"github.com/gin-gonic/gin"
	"github.com/GikoCode/odontoshop/internal/modules/pos/controllers"
)
"@ | Out-File -FilePath "internal\modules\pos\routes\routes.go" -Encoding utf8

# ============================================
# MODULES - ECOMMERCE
# ============================================

@"
package ecommerce

import (
	"github.com/GikoCode/odontoshop/internal/modules/ecommerce/controllers"
	"github.com/GikoCode/odontoshop/internal/modules/ecommerce/services"
	"github.com/GikoCode/odontoshop/internal/modules/ecommerce/routes"
)
"@ | Out-File -FilePath "internal\modules\ecommerce\module.go" -Encoding utf8

@"
package controllers

import (
	"github.com/gin-gonic/gin"
	"github.com/GikoCode/odontoshop/internal/modules/ecommerce/services"
)
"@ | Out-File -FilePath "internal\modules\ecommerce\controllers\product.go" -Encoding utf8

@"
package controllers

import (
	"github.com/gin-gonic/gin"
	"github.com/GikoCode/odontoshop/internal/modules/ecommerce/services"
)
"@ | Out-File -FilePath "internal\modules\ecommerce\controllers\cart.go" -Encoding utf8

@"
package controllers

import (
	"github.com/gin-gonic/gin"
	"github.com/GikoCode/odontoshop/internal/modules/ecommerce/services"
)
"@ | Out-File -FilePath "internal\modules\ecommerce\controllers\order.go" -Encoding utf8

@"
package services

import (
	"github.com/GikoCode/odontoshop/internal/core/domain/inventory"
	"github.com/GikoCode/odontoshop/internal/core/domain/sale"
	"github.com/GikoCode/odontoshop/internal/core/events"
)
"@ | Out-File -FilePath "internal\modules\ecommerce\services\ecommerce_order.go" -Encoding utf8

@"
package services

import (
	"github.com/GikoCode/odontoshop/internal/core/domain/product"
	"github.com/GikoCode/odontoshop/internal/infrastructure/cache"
)
"@ | Out-File -FilePath "internal\modules\ecommerce\services\cart.go" -Encoding utf8

@"
package routes

import (
	"github.com/gin-gonic/gin"
	"github.com/GikoCode/odontoshop/internal/modules/ecommerce/controllers"
)
"@ | Out-File -FilePath "internal\modules\ecommerce\routes\routes.go" -Encoding utf8

# ============================================
# MODULES - AUTH
# ============================================

@"
package auth

import (
	"github.com/GikoCode/odontoshop/internal/modules/auth/controllers"
	"github.com/GikoCode/odontoshop/internal/modules/auth/services"
	"github.com/GikoCode/odontoshop/internal/modules/auth/routes"
	"github.com/GikoCode/odontoshop/internal/modules/auth/middleware"
)
"@ | Out-File -FilePath "internal\modules\auth\module.go" -Encoding utf8

@"
package controllers

import (
	"github.com/gin-gonic/gin"
	"github.com/GikoCode/odontoshop/internal/modules/auth/services"
)
"@ | Out-File -FilePath "internal\modules\auth\controllers\auth.go" -Encoding utf8

@"
package services

import (
	"github.com/golang-jwt/jwt/v5"
)
"@ | Out-File -FilePath "internal\modules\auth\services\auth.go" -Encoding utf8

@"
package middleware

import (
	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
)
"@ | Out-File -FilePath "internal\modules\auth\middleware\jwt.go" -Encoding utf8

@"
package routes

import (
	"github.com/gin-gonic/gin"
	"github.com/GikoCode/odontoshop/internal/modules/auth/controllers"
)
"@ | Out-File -FilePath "internal\modules\auth\routes\routes.go" -Encoding utf8

# ============================================
# CORE - DOMAIN - PRODUCT
# ============================================

@"
package product

import (
	"time"
	"github.com/google/uuid"
)
"@ | Out-File -FilePath "internal\core\domain\product\entity.go" -Encoding utf8

@"
package product

import (
	"context"
	"gorm.io/gorm"
)
"@ | Out-File -FilePath "internal\core\domain\product\repository.go" -Encoding utf8

@"
package product

import (
	"context"
	"github.com/GikoCode/odontoshop/internal/core/events"
)
"@ | Out-File -FilePath "internal\core\domain\product\service.go" -Encoding utf8

# ============================================
# CORE - DOMAIN - INVENTORY
# ============================================

@"
package inventory

import (
	"time"
	"github.com/google/uuid"
)
"@ | Out-File -FilePath "internal\core\domain\inventory\entity.go" -Encoding utf8

@"
package inventory

import (
	"context"
	"gorm.io/gorm"
)
"@ | Out-File -FilePath "internal\core\domain\inventory\repository.go" -Encoding utf8

@"
package inventory

import (
	"context"
	"github.com/GikoCode/odontoshop/internal/core/events"
)
"@ | Out-File -FilePath "internal\core\domain\inventory\service.go" -Encoding utf8

@"
package inventory

import (
	"context"
	"gorm.io/gorm"
	"github.com/GikoCode/odontoshop/internal/core/events"
	"github.com/GikoCode/odontoshop/internal/infrastructure/cache"
)
"@ | Out-File -FilePath "internal\core\domain\inventory\inventory_sync.go" -Encoding utf8

# ============================================
# CORE - DOMAIN - CUSTOMER
# ============================================

@"
package customer

import (
	"time"
	"github.com/google/uuid"
)
"@ | Out-File -FilePath "internal\core\domain\customer\entity.go" -Encoding utf8

@"
package customer

import (
	"context"
	"gorm.io/gorm"
)
"@ | Out-File -FilePath "internal\core\domain\customer\repository.go" -Encoding utf8

@"
package customer

import (
	"context"
)
"@ | Out-File -FilePath "internal\core\domain\customer\service.go" -Encoding utf8

# ============================================
# CORE - DOMAIN - SALE
# ============================================

@"
package sale

import (
	"time"
	"github.com/google/uuid"
)
"@ | Out-File -FilePath "internal\core\domain\sale\entity.go" -Encoding utf8

@"
package sale

import (
	"context"
	"gorm.io/gorm"
)
"@ | Out-File -FilePath "internal\core\domain\sale\repository.go" -Encoding utf8

@"
package sale

import (
	"context"
	"github.com/GikoCode/odontoshop/internal/core/domain/inventory"
	"github.com/GikoCode/odontoshop/internal/core/events"
)
"@ | Out-File -FilePath "internal\core\domain\sale\service.go" -Encoding utf8

# ============================================
# CORE - EVENTS
# ============================================

@"
package events

import (
	"github.com/GikoCode/odontoshop/internal/infrastructure/messaging"
)
"@ | Out-File -FilePath "internal\core\events\event_bus.go" -Encoding utf8

@"
package handlers

import (
	"context"
	"github.com/GikoCode/odontoshop/internal/core/events"
)
"@ | Out-File -FilePath "internal\core\events\handlers\inventory_reserved.go" -Encoding utf8

@"
package handlers

import (
	"context"
	"github.com/GikoCode/odontoshop/internal/core/events"
)
"@ | Out-File -FilePath "internal\core\events\handlers\sale_completed.go" -Encoding utf8

@"
package handlers

import (
	"context"
	"github.com/GikoCode/odontoshop/internal/core/events"
)
"@ | Out-File -FilePath "internal\core\events\handlers\stock_low.go" -Encoding utf8

@"
package publishers

import (
	"github.com/GikoCode/odontoshop/internal/infrastructure/messaging"
)
"@ | Out-File -FilePath "internal\core\events\publishers\inventory.go" -Encoding utf8

# ============================================
# CORE - DATABASE
# ============================================

@"
package database

import (
	"gorm.io/gorm"
	"gorm.io/driver/postgres"
	"github.com/GikoCode/odontoshop/internal/config"
)
"@ | Out-File -FilePath "internal\core\database\connection.go" -Encoding utf8

@"
package migrations

import (
	"gorm.io/gorm"
)
"@ | Out-File -FilePath "internal\core\database\migrations\migrations.go" -Encoding utf8

@"
package seeds

import (
	"gorm.io/gorm"
	"github.com/GikoCode/odontoshop/internal/core/domain/product"
)
"@ | Out-File -FilePath "internal\core\database\seeds\seeds.go" -Encoding utf8

# ============================================
# INFRASTRUCTURE
# ============================================

@"
package cache

import (
	"context"
	"github.com/redis/go-redis/v9"
)
"@ | Out-File -FilePath "internal\infrastructure\cache\redis.go" -Encoding utf8

@"
package messaging

import (
	"github.com/streadway/amqp"
)
"@ | Out-File -FilePath "internal\infrastructure\messaging\rabbitmq.go" -Encoding utf8

@"
package storage

import (
	"io"
)
"@ | Out-File -FilePath "internal\infrastructure\storage\file_upload.go" -Encoding utf8

# ============================================
# SHARED
# ============================================

@"
package guards

import (
	"github.com/gin-gonic/gin"
)
"@ | Out-File -FilePath "internal\shared\guards\auth.go" -Encoding utf8

@"
package middleware

import (
	"github.com/gin-gonic/gin"
)
"@ | Out-File -FilePath "internal\shared\middleware\cors.go" -Encoding utf8

@"
package middleware

import (
	"github.com/gin-gonic/gin"
)
"@ | Out-File -FilePath "internal\shared\middleware\logger.go" -Encoding utf8

@"
package utils

import (
	"github.com/gin-gonic/gin"
)
"@ | Out-File -FilePath "internal\shared\utils\response.go" -Encoding utf8

"package utils" | Out-File -FilePath "internal\shared\utils\pagination.go" -Encoding utf8

# ============================================
# PKG - COMMON
# ============================================

@"
package types

import (
	"github.com/google/uuid"
)
"@ | Out-File -FilePath "pkg\common\types\product.go" -Encoding utf8

@"
package types

import (
	"github.com/google/uuid"
)
"@ | Out-File -FilePath "pkg\common\types\inventory.go" -Encoding utf8

@"
package types

import (
	"github.com/google/uuid"
	"time"
)
"@ | Out-File -FilePath "pkg\common\types\sale.go" -Encoding utf8

"package constants" | Out-File -FilePath "pkg\common\constants\errors.go" -Encoding utf8
"package constants" | Out-File -FilePath "pkg\common\constants\status.go" -Encoding utf8
"package validators" | Out-File -FilePath "pkg\common\validators\product.go" -Encoding utf8

# ============================================
# DOCKER
# ============================================

@"
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    container_name: odontoshop-db
    environment:
      POSTGRES_DB: odontoshop
      POSTGRES_USER: admin
      POSTGRES_PASSWORD: password123
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    container_name: odontoshop-redis
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

  rabbitmq:
    image: rabbitmq:3-management-alpine
    container_name: odontoshop-rabbitmq
    environment:
      RABBITMQ_DEFAULT_USER: admin
      RABBITMQ_DEFAULT_PASS: password123
    ports:
      - "5672:5672"
      - "15672:15672"
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq

volumes:
  postgres_data:
  redis_data:
  rabbitmq_data:
"@ | Out-File -FilePath "deployments\docker\docker-compose.yml" -Encoding utf8

@"
FROM golang:1.21-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -o /api ./cmd/api

FROM alpine:latest

WORKDIR /app

COPY --from=builder /api .

EXPOSE 3001

CMD ["./api"]
"@ | Out-File -FilePath "deployments\docker\Dockerfile" -Encoding utf8

# ============================================
# Makefile
# ============================================

@"
.PHONY: help build run test clean docker-up docker-down

help:
	@echo "Available commands:"
	@echo "  make build      - Build the application"
	@echo "  make run        - Run the application"
	@echo "  make test       - Run tests"
	@echo "  make clean      - Clean build artifacts"
	@echo "  make docker-up  - Start Docker containers"
	@echo "  make docker-down - Stop Docker containers"

build:
	go build -o bin/api.exe ./cmd/api

run:
	go run ./cmd/api/main.go

test:
	go test ./... -v

clean:
	if exist bin rmdir /s /q bin

docker-up:
	docker-compose -f deployments/docker/docker-compose.yml up -d

docker-down:
	docker-compose -f deployments/docker/docker-compose.yml down
"@ | Out-File -FilePath "Makefile" -Encoding utf8
 