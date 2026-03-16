package database

import (
	"fmt"
	"log"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

var DB *gorm.DB

// Ahora acepta 'dsn', que es la cadena que armó tu config
func NewConnection(dsn string) *gorm.DB {
	var err error

	// Si dsn viene vacío por algún error de config, fallará aquí
	DB, err = gorm.Open(postgres.Open(dsn), &gorm.Config{})

	if err != nil {
		log.Fatal("❌ Error al conectar a la base de datos: ", err)
	}

	fmt.Println("🚀 Conexión a PostgreSQL establecida con éxito")

	return DB
}
