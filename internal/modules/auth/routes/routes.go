package routes

import (
	"github.com/GikoCode/odontoshop/internal/modules/auth/controllers"
	"github.com/GikoCode/odontoshop/internal/modules/auth/middleware"
	"github.com/GikoCode/odontoshop/internal/modules/auth/services"
	"github.com/gin-gonic/gin"
)

func RegisterRoutes(router *gin.RouterGroup, authService *services.AuthService) {
	authController := controllers.NewAuthController(authService)

	// Rutas públicas (sin autenticación)
	router.POST("/login", authController.Login)

	// Rutas protegidas (requieren autenticación)
	protected := router.Group("/")
	protected.Use(middleware.RequireAuth(authService))
	{
		protected.GET("/me", authController.Me)
		protected.POST("/logout", authController.Logout)
	}
}
