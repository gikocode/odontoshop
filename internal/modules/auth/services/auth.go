package services

import (
	"context"
	"errors"
	"time"

	"github.com/GikoCode/odontoshop/internal/core/domain/session"
	"github.com/GikoCode/odontoshop/internal/core/domain/user"
	"github.com/GikoCode/odontoshop/internal/shared/utils"
	"github.com/google/uuid"
)

type AuthService struct {
	userRepo    *user.Repository
	sessionRepo *session.Repository
	jwtSecret   string
}

func NewAuthService(
	userRepo *user.Repository,
	sessionRepo *session.Repository,
	jwtSecret string,
) *AuthService {
	return &AuthService{
		userRepo:    userRepo,
		sessionRepo: sessionRepo,
		jwtSecret:   jwtSecret,
	}
}

type LoginInput struct {
	Email     string
	Password  string
	UserAgent *string
	IPAddress *string
}

type LoginResponse struct {
	User         *user.User
	AccessToken  string
	RefreshToken string
	ExpiresIn    int64
}

// Login autentica un usuario y genera tokens
func (s *AuthService) Login(ctx context.Context, input LoginInput) (*LoginResponse, error) {
	// 1. Buscar usuario por email
	u, err := s.userRepo.FindByEmail(ctx, input.Email)
	if err != nil {
		return nil, err
	}
	if u == nil {
		return nil, errors.New("credenciales inválidas")
	}

	// 2. Verificar estado del usuario
	if u.Status != user.UserStatusActive {
		return nil, errors.New("usuario inactivo o suspendido")
	}

	// 3. Verificar contraseña
	if !utils.CheckPassword(input.Password, u.PasswordHash) {
		return nil, errors.New("credenciales inválidas")
	}

	// 4. Extraer roles
	roleNames := make([]string, len(u.Roles))
	for i, role := range u.Roles {
		roleNames[i] = role.Name
	}

	// 5. Generar Access Token (15 minutos)
	accessTokenDuration := 15 * time.Minute
	accessToken, tokenID, err := utils.GenerateJWT(
		u.ID,
		u.Email,
		string(u.UserType),
		roleNames,
		s.jwtSecret,
		accessTokenDuration,
	)
	if err != nil {
		return nil, err
	}

	// 6. Generar Refresh Token (7 días)
	refreshTokenDuration := 7 * 24 * time.Hour
	refreshToken, _, err := utils.GenerateJWT(
		u.ID,
		u.Email,
		string(u.UserType),
		roleNames,
		s.jwtSecret,
		refreshTokenDuration,
	)
	if err != nil {
		return nil, err
	}

	// 7. Guardar sesión
	userSession := &session.UserSession{
		UserID:       u.ID,
		TokenID:      tokenID,
		RefreshToken: &refreshToken,
		UserAgent:    input.UserAgent,
		IPAddress:    input.IPAddress,
		ExpiresAt:    time.Now().Add(refreshTokenDuration),
	}

	if err := s.sessionRepo.Create(ctx, userSession); err != nil {
		return nil, err
	}

	// 8. Actualizar last_login_at
	_ = s.userRepo.UpdateLastLogin(ctx, u.ID)

	return &LoginResponse{
		User:         u,
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		ExpiresIn:    int64(accessTokenDuration.Seconds()),
	}, nil
}

// Logout revoca la sesión del usuario
func (s *AuthService) Logout(ctx context.Context, tokenID uuid.UUID) error {
	return s.sessionRepo.RevokeByTokenID(ctx, tokenID)
}

// ValidateToken valida un token y verifica que la sesión esté activa
func (s *AuthService) ValidateToken(ctx context.Context, tokenString string) (*user.User, error) {
	// 1. Parsear y validar JWT
	claims, err := utils.ValidateJWT(tokenString, s.jwtSecret)
	if err != nil {
		return nil, err
	}

	// 2. Parsear token ID
	tokenID, err := uuid.Parse(claims.ID)
	if err != nil {
		return nil, errors.New("token ID inválido")
	}

	// 3. Verificar que la sesión exista y esté activa
	userSession, err := s.sessionRepo.FindByTokenID(ctx, tokenID)
	if err != nil {
		return nil, err
	}
	if userSession == nil || userSession.IsRevoked {
		return nil, errors.New("sesión inválida o revocada")
	}

	// 4. Obtener usuario completo
	u, err := s.userRepo.FindByID(ctx, claims.UserID)
	if err != nil {
		return nil, err
	}
	if u == nil {
		return nil, errors.New("usuario no encontrado")
	}

	return u, nil
}

// Me obtiene la información del usuario autenticado
func (s *AuthService) Me(ctx context.Context, userID uuid.UUID) (*user.User, error) {
	return s.userRepo.FindByID(ctx, userID)
}
