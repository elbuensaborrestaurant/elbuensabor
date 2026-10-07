package auth

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/saborurbano/api_restaurant/internal/httputil"
)

type Handler struct {
	repo          *Repository
	sessionExpiry time.Duration
}

func NewHandler(pool *pgxpool.Pool, sessionExpiry time.Duration) *Handler {
	return &Handler{repo: NewRepository(pool), sessionExpiry: sessionExpiry}
}

func (h *Handler) Login(w http.ResponseWriter, r *http.Request) {
	var input LoginInput
	if err := json.NewDecoder(io.LimitReader(r.Body, 1<<20)).Decode(&input); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "JSON inválido o mal formado")
		return
	}
	input.Username = strings.TrimSpace(input.Username)
	if input.Username == "" || input.Password == "" {
		httputil.WriteError(w, http.StatusUnprocessableEntity, "VALIDATION_ERROR", "Usuario y contraseña son obligatorios")
		return
	}
	session, err := h.repo.Login(r.Context(), input.Username, input.Password, h.sessionExpiry)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "INTERNAL_SERVER_ERROR", err.Error())
		return
	}
	if session.Token == "" {
		httputil.WriteError(w, http.StatusUnauthorized, "INVALID_CREDENTIALS", "Usuario o contraseña incorrectos.")
		return
	}
	httputil.WriteSuccess(w, http.StatusOK, session)
}

func (h *Handler) Me(w http.ResponseWriter, r *http.Request) {
	token := bearerToken(r)
	if token == "" {
		httputil.WriteError(w, http.StatusUnauthorized, "UNAUTHORIZED", "La sesión no es válida o ha expirado.")
		return
	}
	user, err := h.repo.GetSessionUser(r.Context(), token)
	if errors.Is(err, pgx.ErrNoRows) {
		httputil.WriteError(w, http.StatusUnauthorized, "UNAUTHORIZED", "La sesión no es válida o ha expirado.")
		return
	}
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "INTERNAL_SERVER_ERROR", err.Error())
		return
	}
	httputil.WriteSuccess(w, http.StatusOK, user)
}

func (h *Handler) Logout(w http.ResponseWriter, r *http.Request) {
	if token := bearerToken(r); token != "" {
		if err := h.repo.Logout(r.Context(), token); err != nil {
			httputil.WriteError(w, http.StatusInternalServerError, "INTERNAL_SERVER_ERROR", err.Error())
			return
		}
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) RegisterRoutes(mux *http.ServeMux) {
	mux.HandleFunc("POST /api/v1/auth/login", h.Login)
	mux.HandleFunc("GET /api/v1/auth/me", h.Me)
	mux.HandleFunc("POST /api/v1/auth/logout", h.Logout)
}

func bearerToken(r *http.Request) string {
	scheme, token, ok := strings.Cut(r.Header.Get("Authorization"), " ")
	if !ok || !strings.EqualFold(scheme, "Bearer") {
		return ""
	}
	return strings.TrimSpace(token)
}
