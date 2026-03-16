package middleware

import (
	"net/http"
	"strings"

	"github.com/GikoCode/odontoshop/internal/modules/auth/services"
	"github.com/gin-gonic/gin"
)

// RequireAuth middleware que valida JWT
func RequireAuth(authService *services.AuthService) gin.HandlerFunc {
	return func(ctx *gin.Context) {
		// 1. Extraer token del header Authorization
		authHeader := ctx.GetHeader("Authorization")
		if authHeader == "" {
			ctx.JSON(http.StatusUnauthorized, gin.H{"error": "token no proporcionado"})
			ctx.Abort()
			return
		}

		// 2. Verificar formato "Bearer <token>"
		parts := strings.Split(authHeader, " ")
		if len(parts) != 2 || parts[0] != "Bearer" {
			ctx.JSON(http.StatusUnauthorized, gin.H{"error": "formato de token inválido"})
			ctx.Abort()
			return
		}

		tokenString := parts[1]

		// 3. Validar token
		user, err := authService.ValidateToken(ctx.Request.Context(), tokenString)
		if err != nil {
			ctx.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
			ctx.Abort()
			return
		}

		// 4. Inyectar usuario en el contexto
		ctx.Set("user", user)
		ctx.Set("user_id", user.ID)
		ctx.Set("user_type", user.UserType)

		// Extraer token ID del JWT y guardarlo en contexto
		// (necesitarías parsear el token de nuevo, o incluirlo en user)

		ctx.Next()
	}
}
