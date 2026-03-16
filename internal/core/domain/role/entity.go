package role

import (
	"time"

	"github.com/google/uuid"
)

type Role struct {
	ID           uuid.UUID `gorm:"type:uuid;primary_key;default:uuid_generate_v4()" json:"id"`
	Name         string    `gorm:"type:varchar(50);uniqueIndex;not null" json:"name"`
	DisplayName  string    `gorm:"type:varchar(100);not null" json:"display_name"`
	Description  *string   `gorm:"type:text" json:"description,omitempty"`
	IsSystemRole bool      `gorm:"default:false" json:"is_system_role"`
	CreatedAt    time.Time `gorm:"autoCreateTime" json:"created_at"`
	UpdatedAt    time.Time `gorm:"autoUpdateTime" json:"updated_at"`

	// Relaciones
	Permissions []Permission `gorm:"many2many:role_permissions;" json:"permissions,omitempty"`
}

func (Role) TableName() string {
	return "roles"
}

type Permission struct {
	ID          uuid.UUID `gorm:"type:uuid;primary_key;default:uuid_generate_v4()" json:"id"`
	Resource    string    `gorm:"type:varchar(50);not null" json:"resource"`
	Action      string    `gorm:"type:varchar(50);not null" json:"action"`
	Description *string   `gorm:"type:text" json:"description,omitempty"`
	CreatedAt   time.Time `gorm:"autoCreateTime" json:"created_at"`
}

func (Permission) TableName() string {
	return "permissions"
}

// UserRole - Tabla pivot para users <-> roles
type UserRole struct {
	UserID     uuid.UUID  `gorm:"type:uuid;primaryKey" json:"user_id"`
	RoleID     uuid.UUID  `gorm:"type:uuid;primaryKey" json:"role_id"`
	AssignedAt time.Time  `gorm:"autoCreateTime" json:"assigned_at"`
	AssignedBy *uuid.UUID `gorm:"type:uuid" json:"assigned_by,omitempty"`
	ExpiresAt  *time.Time `gorm:"type:timestamptz" json:"expires_at,omitempty"`
}

func (UserRole) TableName() string {
	return "user_roles"
}

// RolePermission - Tabla pivot para roles <-> permissions
type RolePermission struct {
	RoleID       uuid.UUID `gorm:"type:uuid;primaryKey" json:"role_id"`
	PermissionID uuid.UUID `gorm:"type:uuid;primaryKey" json:"permission_id"`
	GrantedAt    time.Time `gorm:"autoCreateTime" json:"granted_at"`
}

func (RolePermission) TableName() string {
	return "role_permissions"
}
