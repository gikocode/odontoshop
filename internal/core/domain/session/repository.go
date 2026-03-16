package session

import (
	"context"
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

// Create crea una nueva sesión
func (r *Repository) Create(ctx context.Context, session *UserSession) error {
	return r.db.WithContext(ctx).Create(session).Error
}

// FindByTokenID busca sesión por JTI
func (r *Repository) FindByTokenID(ctx context.Context, tokenID uuid.UUID) (*UserSession, error) {
	var session UserSession
	err := r.db.WithContext(ctx).
		Where("token_id = ? AND is_revoked = false AND expires_at > ?", tokenID, time.Now()).
		First(&session).
		Error

	if err == gorm.ErrRecordNotFound {
		return nil, nil
	}
	return &session, err
}

// RevokeByTokenID revoca una sesión específica
func (r *Repository) RevokeByTokenID(ctx context.Context, tokenID uuid.UUID) error {
	return r.db.WithContext(ctx).
		Model(&UserSession{}).
		Where("token_id = ?", tokenID).
		Update("is_revoked", true).
		Error
}

// RevokeAllByUserID revoca todas las sesiones de un usuario
func (r *Repository) RevokeAllByUserID(ctx context.Context, userID uuid.UUID) error {
	return r.db.WithContext(ctx).
		Model(&UserSession{}).
		Where("user_id = ?", userID).
		Update("is_revoked", true).
		Error
}

// CleanupExpired elimina sesiones expiradas
func (r *Repository) CleanupExpired(ctx context.Context) error {
	return r.db.WithContext(ctx).
		Where("expires_at < ?", time.Now()).
		Delete(&UserSession{}).
		Error
}
