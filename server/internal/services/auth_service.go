package services

import (
	"errors"
	"strings"

	"gorm.io/gorm"
	"notes/server/internal/models"
	"notes/server/internal/schemas"
	"notes/server/internal/utils"
)

var (
	ErrUserExists           = errors.New("user already exists")
	ErrInvalidCredentials   = errors.New("invalid credentials")
	ErrInvalidSignupPayload = errors.New("name, email, and password are required")
	ErrInvalidLoginPayload  = errors.New("email and password are required")
	ErrWeakPassword         = errors.New("password must be at least 8 characters")
)

type AuthService interface {
	Signup(payload schemas.SignupRequest) (schemas.AuthResponse, error)
	Login(payload schemas.LoginRequest) (schemas.AuthResponse, error)
	Me(userID string) (schemas.AuthUser, error)
}

type GormAuthService struct {
	db        *gorm.DB
	jwtSecret string
}

func NewGormAuthService(conn *gorm.DB, jwtSecret string) *GormAuthService {
	return &GormAuthService{db: conn, jwtSecret: jwtSecret}
}

func (service *GormAuthService) Signup(payload schemas.SignupRequest) (schemas.AuthResponse, error) {
	name := strings.TrimSpace(payload.Name)
	email := strings.TrimSpace(strings.ToLower(payload.Email))
	if name == "" || email == "" || payload.Password == "" {
		return schemas.AuthResponse{}, ErrInvalidSignupPayload
	}
	if len(payload.Password) < 8 {
		return schemas.AuthResponse{}, ErrWeakPassword
	}

	var existing models.User
	err := service.db.Where("email = ?", email).First(&existing).Error
	if err == nil {
		return schemas.AuthResponse{}, ErrUserExists
	}
	if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
		return schemas.AuthResponse{}, err
	}

	hashedPassword, err := utils.HashPassword(payload.Password)
	if err != nil {
		return schemas.AuthResponse{}, err
	}

	user := models.User{
		Name:         name,
		Email:        email,
		PasswordHash: hashedPassword,
	}
	if err := service.db.Create(&user).Error; err != nil {
		return schemas.AuthResponse{}, err
	}

	return service.buildAuthResponse(user)
}

func (service *GormAuthService) Login(payload schemas.LoginRequest) (schemas.AuthResponse, error) {
	email := strings.TrimSpace(strings.ToLower(payload.Email))
	if email == "" || payload.Password == "" {
		return schemas.AuthResponse{}, ErrInvalidLoginPayload
	}

	var user models.User
	if err := service.db.Where("email = ?", email).First(&user).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return schemas.AuthResponse{}, ErrInvalidCredentials
		}
		return schemas.AuthResponse{}, err
	}

	if err := utils.ComparePassword(user.PasswordHash, payload.Password); err != nil {
		return schemas.AuthResponse{}, ErrInvalidCredentials
	}

	return service.buildAuthResponse(user)
}

func (service *GormAuthService) buildAuthResponse(user models.User) (schemas.AuthResponse, error) {
	token, err := utils.GenerateAuthToken(service.jwtSecret, user.ID, user.Email)
	if err != nil {
		return schemas.AuthResponse{}, err
	}

	tokenRecord := models.Token{
		UserID:    user.ID,
		TokenHash: utils.HashToken(token),
	}
	if err := service.db.Create(&tokenRecord).Error; err != nil {
		return schemas.AuthResponse{}, err
	}

	return schemas.AuthResponse{
		Token: token,
		User: schemas.AuthUser{
			ID:    user.ID,
			Name:  user.Name,
			Email: user.Email,
		},
	}, nil
}

func (service *GormAuthService) Me(userID string) (schemas.AuthUser, error) {
	var user models.User
	if err := service.db.Select("id", "name", "email").Where("id = ?", userID).First(&user).Error; err != nil {
		return schemas.AuthUser{}, err
	}

	return schemas.AuthUser{
		ID:    user.ID,
		Name:  user.Name,
		Email: user.Email,
	}, nil
}
