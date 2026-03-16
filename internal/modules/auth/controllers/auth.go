package controllers

import (
	"net/http"

	"github.com/GikoCode/odontoshop/internal/modules/auth/services"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type AuthController struct {
	authService *services.AuthService
}

func NewAuthController(authService *services.AuthService) *AuthController {
	return &AuthController{authService: authService}
}

// LoginRequest DTO
type LoginRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required,min=6"`
}

// Login maneja POST /auth/login
func (c *AuthController) Login(ctx *gin.Context) {
	var req LoginRequest

	if err := ctx.ShouldBindJSON(&req); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Obtener user agent y IP
	userAgent := ctx.Request.UserAgent()
	ipAddress := ctx.ClientIP()

	// Llamar al servicio
	response, err := c.authService.Login(ctx.Request.Context(), services.LoginInput{
		Email:     req.Email,
		Password:  req.Password,
		UserAgent: &userAgent,
		IPAddress: &ipAddress,
	})

	if err != nil {
		ctx.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
		return
	}

	// Respuesta exitosa
	ctx.JSON(http.StatusOK, gin.H{
		"user": gin.H{
			"id":        response.User.ID,
			"email":     response.User.Email,
			"user_type": response.User.UserType,
			"status":    response.User.Status,
			"employee":  response.User.Employee,
			"customer":  response.User.Customer,
			"roles":     response.User.Roles,
		},
		"access_token":  response.AccessToken,
		"refresh_token": response.RefreshToken,
		"token_type":    "Bearer",
		"expires_in":    response.ExpiresIn,
	})
}

// Logout maneja POST /auth/logout
func (c *AuthController) Logout(ctx *gin.Context) {
	// Obtener token ID del contexto (inyectado por middleware)
	tokenID, exists := ctx.Get("token_id")
	if !exists {
		ctx.JSON(http.StatusUnauthorized, gin.H{"error": "token no encontrado"})
		return
	}

	err := c.authService.Logout(ctx.Request.Context(), tokenID.(uuid.UUID))
	if err != nil {
		ctx.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	ctx.JSON(http.StatusOK, gin.H{"message": "Sesión cerrada exitosamente"})
}

// Me maneja GET /auth/me
func (c *AuthController) Me(ctx *gin.Context) {
	// Obtener user ID del contexto (inyectado por middleware)
	userID, exists := ctx.Get("user_id")
	if !exists {
		ctx.JSON(http.StatusUnauthorized, gin.H{"error": "usuario no autenticado"})
		return
	}

	user, err := c.authService.Me(ctx.Request.Context(), userID.(uuid.UUID))
	if err != nil {
		ctx.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	ctx.JSON(http.StatusOK, gin.H{
		"user": user,
	})
}
