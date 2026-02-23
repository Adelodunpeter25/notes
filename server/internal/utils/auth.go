package utils

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"

	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
)

var ErrInvalidTokenSecret = errors.New("jwt secret is required")

type AuthClaims struct {
	UserID string `json:"user_id"`
	Email  string `json:"email"`
	jwt.RegisteredClaims
}

func HashPassword(password string) (string, error) {
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return "", err
	}

	return string(hashedPassword), nil
}

func ComparePassword(hashedPassword, password string) error {
	return bcrypt.CompareHashAndPassword([]byte(hashedPassword), []byte(password))
}

func GenerateAuthToken(secret, userID, email string) (string, error) {
	if secret == "" {
		return "", ErrInvalidTokenSecret
	}

	claims := AuthClaims{
		UserID: userID,
		Email:  email,
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(secret))
}

func ParseAuthToken(secret, rawToken string) (AuthClaims, error) {
	if secret == "" {
		return AuthClaims{}, ErrInvalidTokenSecret
	}

	parsedToken, err := jwt.ParseWithClaims(rawToken, &AuthClaims{}, func(token *jwt.Token) (interface{}, error) {
		return []byte(secret), nil
	})
	if err != nil {
		return AuthClaims{}, err
	}

	claims, ok := parsedToken.Claims.(*AuthClaims)
	if !ok || !parsedToken.Valid {
		return AuthClaims{}, errors.New("invalid token")
	}

	return *claims, nil
}

func HashToken(token string) string {
	hash := sha256.Sum256([]byte(token))
	return hex.EncodeToString(hash[:])
}
