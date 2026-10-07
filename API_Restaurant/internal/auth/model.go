package auth

import "time"

type Role struct {
	ID     string `json:"id"`
	Nombre string `json:"nombre"`
	Tipo   string `json:"tipo"`
}

type User struct {
	ID          string     `json:"id"`
	Nombre      string     `json:"nombre"`
	Apellido    *string    `json:"apellido"`
	Email       *string    `json:"email"`
	Username    string     `json:"username"`
	Rol         Role       `json:"rol"`
	UltimoLogin *time.Time `json:"ultimo_login,omitempty"`
}

type LoginInput struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

type LoginResponse struct {
	Token     string    `json:"token"`
	ExpiresAt time.Time `json:"expires_at"`
	Usuario   User      `json:"usuario"`
}
