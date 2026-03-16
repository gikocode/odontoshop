package middleware

import (
	"net/http"

	"github.com/GikoCode/odontoshop/internal/core/domain/user"
	"github.com/gin-gonic/gin"
)

// RequireRole middleware que verifica roles específicos
func RequireRole(allowedRoles ...string) gin.HandlerFunc {
	return func(ctx *gin.Context) {
		// Obtener usuario del contexto (inyectado por RequireAuth)
		userInterface, exists := ctx.Get("user")
		if !exists {
			ctx.JSON(http.StatusUnauthorized, gin.H{"error": "usuario no autenticado"})
			ctx.Abort()
			return
		}

		u := userInterface.(*user.User)

		// Verificar si el usuario tiene alguno de los roles permitidos
		hasRole := false
		for _, userRole := range u.Roles {
			for _, allowedRole := range allowedRoles {
				if userRole.Name == allowedRole {
					hasRole = true
					break
				}
			}
			if hasRole {
				break
			}
		}

		if !hasRole {
			ctx.JSON(http.StatusForbidden, gin.H{"error": "permisos insuficientes"})
			ctx.Abort()
			return
		}

		ctx.Next()
	}
}

// RequireEmployeeOnly middleware que solo permite empleados
func RequireEmployeeOnly() gin.HandlerFunc {
	return func(ctx *gin.Context) {
		userType, exists := ctx.Get("user_type")
		if !exists {
			ctx.JSON(http.StatusUnauthorized, gin.H{"error": "usuario no autenticado"})
			ctx.Abort()
			return
		}

		if userType != user.UserTypeEmployee {
			ctx.JSON(http.StatusForbidden, gin.H{"error": "solo empleados pueden acceder"})
			ctx.Abort()
			return
		}

		ctx.Next()
	}
}

// RequireCustomerOnly middleware que solo permite clientes
func RequireCustomerOnly() gin.HandlerFunc {
	return func(ctx *gin.Context) {
		userType, exists := ctx.Get("user_type")
		if !exists {
			ctx.JSON(http.StatusUnauthorized, gin.H{"error": "usuario no autenticado"})
			ctx.Abort()
			return
		}

		if userType != user.UserTypeCustomer {
			ctx.JSON(http.StatusForbidden, gin.H{"error": "solo clientes pueden acceder"})
			ctx.Abort()
			return
		}

		ctx.Next()
	}
}
