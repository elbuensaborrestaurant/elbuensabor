package auth

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"
)

type Repository struct {
	pool *pgxpool.Pool
}

func NewRepository(pool *pgxpool.Pool) *Repository {
	return &Repository{pool: pool}
}

func (repo *Repository) Login(ctx context.Context, username, password string, expiry time.Duration) (LoginResponse, error) {
	var user User
	var passwordHash string
	var lastLogin pgtype.Timestamptz
	err := repo.pool.QueryRow(ctx, `
		SELECT u.id::text, u.nombre, u.apellido, u.email, u.username,
		       r.id::text, r.nombre, r.tipo::text, u.password_hash, u.ultimo_login
		FROM personal.usuarios AS u
		JOIN personal.roles AS r ON r.id = u.rol_id
		WHERE u.username = $1
		  AND u.estado = 'activo'
		  AND u.deleted_at IS NULL
		  AND r.estado = 'activo'
	`, username).Scan(
		&user.ID, &user.Nombre, &user.Apellido, &user.Email, &user.Username,
		&user.Rol.ID, &user.Rol.Nombre, &user.Rol.Tipo, &passwordHash, &lastLogin,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return LoginResponse{}, nil
	}
	if err != nil {
		return LoginResponse{}, fmt.Errorf("consultando usuario: %w", err)
	}
	if bcrypt.CompareHashAndPassword([]byte(passwordHash), []byte(password)) != nil {
		return LoginResponse{}, nil
	}

	tokenBytes := make([]byte, 32)
	if _, err := rand.Read(tokenBytes); err != nil {
		return LoginResponse{}, fmt.Errorf("generando token de sesión: %w", err)
	}
	token := base64.RawURLEncoding.EncodeToString(tokenBytes)
	expiresAt := time.Now().UTC().Add(expiry)
	tx, err := repo.pool.Begin(ctx)
	if err != nil {
		return LoginResponse{}, fmt.Errorf("iniciando sesión de base de datos: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	if _, err := tx.Exec(ctx, `
		INSERT INTO personal.sesiones_usuario (usuario_id, token, expira_en)
		VALUES ($1::uuid, $2, $3)
	`, user.ID, hashToken(token), expiresAt); err != nil {
		return LoginResponse{}, fmt.Errorf("guardando sesión: %w", err)
	}
	if err := tx.QueryRow(ctx, `
		UPDATE personal.usuarios SET ultimo_login = NOW()
		WHERE id = $1::uuid RETURNING ultimo_login
	`, user.ID).Scan(&lastLogin); err != nil {
		return LoginResponse{}, fmt.Errorf("actualizando último acceso: %w", err)
	}
	if err := tx.Commit(ctx); err != nil {
		return LoginResponse{}, fmt.Errorf("confirmando sesión: %w", err)
	}
	if lastLogin.Valid {
		user.UltimoLogin = &lastLogin.Time
	}

	return LoginResponse{Token: token, ExpiresAt: expiresAt, Usuario: user}, nil
}

func (repo *Repository) GetSessionUser(ctx context.Context, token string) (User, error) {
	var user User
	var lastLogin pgtype.Timestamptz
	err := repo.pool.QueryRow(ctx, `
		SELECT u.id::text, u.nombre, u.apellido, u.email, u.username,
		       r.id::text, r.nombre, r.tipo::text, u.ultimo_login
		FROM personal.sesiones_usuario AS s
		JOIN personal.usuarios AS u ON u.id = s.usuario_id
		JOIN personal.roles AS r ON r.id = u.rol_id
		WHERE s.token = $1
		  AND s.expira_en > NOW()
		  AND u.estado = 'activo'
		  AND u.deleted_at IS NULL
		  AND r.estado = 'activo'
	`, hashToken(token)).Scan(
		&user.ID, &user.Nombre, &user.Apellido, &user.Email, &user.Username,
		&user.Rol.ID, &user.Rol.Nombre, &user.Rol.Tipo, &lastLogin,
	)
	if err != nil {
		return User{}, err
	}
	if lastLogin.Valid {
		user.UltimoLogin = &lastLogin.Time
	}
	return user, nil
}

func (repo *Repository) Logout(ctx context.Context, token string) error {
	_, err := repo.pool.Exec(ctx, "DELETE FROM personal.sesiones_usuario WHERE token = $1", hashToken(token))
	if err != nil {
		return fmt.Errorf("eliminando sesión: %w", err)
	}
	return nil
}

func hashToken(token string) string {
	hash := sha256.Sum256([]byte(token))
	return hex.EncodeToString(hash[:])
}
