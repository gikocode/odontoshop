package user

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type Repository struct {
	db *gorm.DB
}

func NewRepository(db *gorm.DB) *Repository {
	return &Repository{db: db}
}

// FindByEmail busca usuario por email (solo activos)
func (r *Repository) FindByEmail(ctx context.Context, email string) (*User, error) {
	var user User
	err := r.db.WithContext(ctx).
		Preload("Employee").
		Preload("Customer").
		Preload("Roles.Permissions").
		Where("email = ? AND deleted_at IS NULL", email).
		First(&user).
		Error

	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	return &user, err
}

// FindByID busca usuario por ID
func (r *Repository) FindByID(ctx context.Context, id uuid.UUID) (*User, error) {
	var user User
	err := r.db.WithContext(ctx).
		Preload("Employee").
		Preload("Customer").
		Preload("Roles.Permissions").
		Where("id = ? AND deleted_at IS NULL", id).
		First(&user).
		Error

	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	return &user, err
}

// Create crea un nuevo usuario
func (r *Repository) Create(ctx context.Context, user *User) error {
	return r.db.WithContext(ctx).Create(user).Error
}

// UpdateLastLogin actualiza el timestamp de último login
func (r *Repository) UpdateLastLogin(ctx context.Context, userID uuid.UUID) error {
	now := time.Now()
	return r.db.WithContext(ctx).
		Model(&User{}).
		Where("id = ?", userID).
		Update("last_login_at", now).
		Error
}

// HasPermission verifica si el usuario tiene un permiso específico
func (r *Repository) HasPermission(ctx context.Context, userID uuid.UUID, resource, action string) (bool, error) {
	var count int64

	err := r.db.WithContext(ctx).
		Table("users").
		Joins("JOIN user_roles ON users.id = user_roles.user_id").
		Joins("JOIN role_permissions ON user_roles.role_id = role_permissions.role_id").
		Joins("JOIN permissions ON role_permissions.permission_id = permissions.id").
		Where("users.id = ? AND permissions.resource = ? AND permissions.action = ?", userID, resource, action).
		Count(&count).
		Error

	return count > 0, err
}
