package main

import (
	"log"
	"strings"
	"time"

	"github.com/GikoCode/odontoshop/internal/config"
	"github.com/GikoCode/odontoshop/internal/core/database"
	"github.com/GikoCode/odontoshop/internal/core/domain/customer"
	"github.com/GikoCode/odontoshop/internal/core/domain/employee"
	"github.com/GikoCode/odontoshop/internal/core/domain/role"
	"github.com/GikoCode/odontoshop/internal/core/domain/session"
	"github.com/GikoCode/odontoshop/internal/core/domain/user"
	authMiddleware "github.com/GikoCode/odontoshop/internal/modules/auth/middleware"
	authRoutes "github.com/GikoCode/odontoshop/internal/modules/auth/routes"
	authServices "github.com/GikoCode/odontoshop/internal/modules/auth/services"
	"github.com/GikoCode/odontoshop/internal/shared/middleware"
	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
)

func main() {
	// 1. Cargar configuración global
	cfg := config.Load()

	// 2. Esperar a que la BD esté lista
	log.Println("Waiting for database to be ready...")
	time.Sleep(5 * time.Second)

	// 3. Conectar a la Base de Datos
	db := database.NewConnection(cfg.Database.URL)

	// 4. Auto-migrate: Crea las tablas si no existen
	db.AutoMigrate(
		&user.User{},
		&employee.Employee{},
		&customer.Customer{},
		&role.Role{},
		&role.Permission{},
		&role.UserRole{},
		&role.RolePermission{},
		&session.UserSession{},
	)

	// 5. Inicializar Repositorios
	userRepo := user.NewRepository(db)
	sessionRepo := session.NewRepository(db)

	// 6. Inicializar Servicios
	authService := authServices.NewAuthService(userRepo, sessionRepo, cfg.Security.JWTSecret)

	// 7. Configurar Router
	router := gin.Default()

	// 8. Middlewares Globales (SIEMPRE PRIMERO)
	origins := strings.Split(cfg.Server.CorsAllowedOrigins, ",")
	router.Use(middleware.SetupCORS(origins))
	router.Use(middleware.SetupLogger())

	// 9. Rutas Públicas
	router.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok", "database": "connected"})
	})

	// 10. Autenticación
	authGroup := router.Group("/api/auth")
	authRoutes.RegisterRoutes(authGroup, authService)

	// 11. Rutas Protegidas de Administración
	adminGroup := router.Group("/api/admin")

	// Aplicamos los Middlewares una sola vez al grupo
	adminGroup.Use(authMiddleware.RequireAuth(authService))
	adminGroup.Use(authMiddleware.RequireEmployeeOnly())
	adminGroup.Use(authMiddleware.RequireRole("admin", "gerente"))

	{
		// Ruta para verificar acceso al panel
		adminGroup.GET("/dashboard", func(c *gin.Context) {
			c.JSON(200, gin.H{"message": "Bienvenido al panel de control"})
		})

		// ✅ RUTA PARA OBTENER LA LISTA DE USUARIOS
		adminGroup.GET("/users", func(c *gin.Context) {
			var users []user.User
			// Preload("Roles") trae la información de los roles de cada usuario
			if err := db.Preload("Roles").Find(&users).Error; err != nil {
				c.JSON(500, gin.H{"error": "No se pudieron obtener los usuarios"})
				return
			}
			c.JSON(200, users)
		})
	}
	// 12. Crear usuario de prueba (Temporal)
	var count int64
	db.Model(&user.User{}).Count(&count)
	if count == 0 {
		// Crear el Rol de Admin
		desc := "Administrador total del sistema"
		adminRole := role.Role{
			Name:        "admin",
			Description: &desc,
		}
		db.FirstOrCreate(&adminRole, role.Role{Name: "admin"})

		// Crear el Usuario
		hashedPassword, _ := bcrypt.GenerateFromPassword([]byte("admin123"), 14)
		testUser := user.User{
			Email:        "admin@odontoshop.com",
			PasswordHash: string(hashedPassword),
			UserType:     user.UserTypeEmployee,
			Status:       user.UserStatusActive,
		}
		db.Create(&testUser)

		// Vincular con el Rol
		userRole := role.UserRole{
			UserID: testUser.ID,
			RoleID: adminRole.ID,
		}
		db.Create(&userRole)

		log.Println("✅ Usuario admin@odontoshop.com creado con rol ADMIN")
	}

	// 13. Iniciar servidor
	log.Printf("🚀 Servidor OdontoShop corriendo en el puerto %s", cfg.Server.Port)
	log.Fatal(router.Run(":" + cfg.Server.Port))
}
