package user

import (
	"time"

	"github.com/GikoCode/odontoshop/internal/core/domain/customer"
	"github.com/GikoCode/odontoshop/internal/core/domain/employee"
	"github.com/GikoCode/odontoshop/internal/core/domain/role"
	"github.com/google/uuid"
)

type UserType string
type UserStatus string

const (
	UserTypeEmployee UserType = "employee"
	UserTypeCustomer UserType = "customer"
)

const (
	UserStatusActive              UserStatus = "active"
	UserStatusInactive            UserStatus = "inactive"
	UserStatusSuspended           UserStatus = "suspended"
	UserStatusPendingVerification UserStatus = "pending_verification"
)

// User - Tabla base de usuarios (tanto empleados como clientes)
type User struct {
	ID            uuid.UUID  `gorm:"type:uuid;primary_key;default:uuid_generate_v4()" json:"id"`
	Email         string     `gorm:"type:varchar(255);not null" json:"email"`
	PasswordHash  string     `gorm:"type:varchar(255);not null" json:"-"` // No exponer en JSON
	UserType      UserType   `gorm:"type:varchar(20);not null" json:"user_type"`
	Status        UserStatus `gorm:"type:varchar(30);default:'active'" json:"status"`
	EmailVerified bool       `gorm:"default:false" json:"email_verified"`
	Phone         *string    `gorm:"type:varchar(20)" json:"phone,omitempty"`
	LastLoginAt   *time.Time `gorm:"type:timestamptz" json:"last_login_at,omitempty"`
	CreatedAt     time.Time  `gorm:"autoCreateTime" json:"created_at"`
	UpdatedAt     time.Time  `gorm:"autoUpdateTime" json:"updated_at"`
	DeletedAt     *time.Time `gorm:"index" json:"deleted_at,omitempty"`

	// Relaciones
	Employee *employee.Employee `gorm:"foreignKey:UserID" json:"employee,omitempty"`
	Customer *customer.Customer `gorm:"foreignKey:UserID" json:"customer,omitempty"`
	Roles    []role.Role        `gorm:"many2many:user_roles;" json:"roles,omitempty"`
}

func (User) TableName() string {
	return "users"
}
