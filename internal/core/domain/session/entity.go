package session

import (
	"time"

	"github.com/google/uuid"
)

type UserSession struct {
	ID           uuid.UUID `gorm:"type:uuid;primary_key;default:uuid_generate_v4()" json:"id"`
	UserID       uuid.UUID `gorm:"type:uuid;not null;index" json:"user_id"`
	TokenID      uuid.UUID `gorm:"type:uuid;not null;uniqueIndex" json:"token_id"` // JTI del JWT
	RefreshToken *string   `gorm:"type:text" json:"-"`                             // No exponer
	UserAgent    *string   `gorm:"type:text" json:"user_agent,omitempty"`
	IPAddress    *string   `gorm:"type:varchar(45)" json:"ip_address,omitempty"`
	IsRevoked    bool      `gorm:"default:false" json:"is_revoked"`
	ExpiresAt    time.Time `gorm:"type:timestamptz;not null" json:"expires_at"`
	CreatedAt    time.Time `gorm:"autoCreateTime" json:"created_at"`
}

func (UserSession) TableName() string {
	return "user_sessions"
}
