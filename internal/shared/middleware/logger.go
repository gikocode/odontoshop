package middleware

import (
	"time"

	"github.com/gin-gonic/gin"
	"github.com/sirupsen/logrus"
)

var log = logrus.New()

// SetupLogger configura el logger de la aplicación
func SetupLogger() gin.HandlerFunc {
	// Configurar formato
	log.SetFormatter(&logrus.JSONFormatter{})

	return func(c *gin.Context) {
		// Timestamp de inicio
		startTime := time.Now()

		// Procesar request
		c.Next()

		// Calcular latencia
		latency := time.Since(startTime)

		// Log de la request
		log.WithFields(logrus.Fields{
			"status":     c.Writer.Status(),
			"method":     c.Request.Method,
			"path":       c.Request.URL.Path,
			"ip":         c.ClientIP(),
			"latency":    latency,
			"user_agent": c.Request.UserAgent(),
		}).Info("HTTP Request")
	}
}
