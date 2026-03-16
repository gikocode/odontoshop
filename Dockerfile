# ============================================
# STAGE 1: Builder
# ============================================ 
# Etapa de compilación
FROM golang:1.26-alpine AS builder

# Instalar dependencias de compilación
RUN apk add --no-cache git make

WORKDIR /app

# Copiar dependencias primero (mejor caching)
COPY go.mod go.sum ./
RUN go mod download

# Copiar código fuente
COPY . .

# Compilar con optimizaciones
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-w -s" -o main ./cmd/api/main.go

# ============================================
# STAGE 2: Production
# ============================================
FROM alpine:latest

# Instalar certificados SSL (necesario para HTTPS)
RUN apk --no-cache add ca-certificates tzdata

# Crear usuario no-root por seguridad
RUN addgroup -g 1000 app && \
    adduser -D -u 1000 -G app app

WORKDIR /home/app

# Copiar binario desde builder
COPY --from=builder /app/main .

# Cambiar ownership
RUN chown -R app:app /home/app

# Usar usuario no-root
USER app

# Exponer puerto (debe coincidir con docker-compose)
EXPOSE 3001

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3001/health || exit 1

# Comando de ejecución
CMD ["./main"]