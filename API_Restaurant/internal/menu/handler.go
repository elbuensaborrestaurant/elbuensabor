package menu

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"github.com/saborurbano/api_restaurant/internal/httputil"
)

type Handler struct {
	repo *Repository
}

func NewHandler(repo *Repository) *Handler {
	return &Handler{repo: repo}
}

func (h *Handler) ListCategorias(w http.ResponseWriter, r *http.Request) {
	cats, err := h.repo.ListCategoriasActivas(r.Context())
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "INTERNAL_SERVER_ERROR", err.Error())
		return
	}

	httputil.WriteSuccess(w, http.StatusOK, cats)
}

func (h *Handler) GetCategoria(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if strings.TrimSpace(id) == "" {
		httputil.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "El ID de la categoría es requerido")
		return
	}

	cat, err := h.repo.GetCategoriaByID(r.Context(), id)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			httputil.WriteError(w, http.StatusNotFound, "NOT_FOUND", "La categoría solicitada no existe")
			return
		}
		httputil.WriteError(w, http.StatusInternalServerError, "INTERNAL_SERVER_ERROR", err.Error())
		return
	}

	httputil.WriteSuccess(w, http.StatusOK, cat)
}

func (h *Handler) CreateCategoria(w http.ResponseWriter, r *http.Request) {
	var input CreateCategoriaInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "JSON inválido o mal formado")
		return
	}

	if strings.TrimSpace(input.Nombre) == "" {
		httputil.WriteError(w, http.StatusUnprocessableEntity, "VALIDATION_ERROR", "El campo 'nombre' es obligatorio")
		return
	}

	cat, err := h.repo.CreateCategoria(r.Context(), input)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "INTERNAL_SERVER_ERROR", err.Error())
		return
	}

	httputil.WriteSuccess(w, http.StatusCreated, cat)
}

func (h *Handler) UpdateCategoria(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if strings.TrimSpace(id) == "" {
		httputil.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "El ID de la categoría es requerido")
		return
	}

	var input UpdateCategoriaInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "JSON inválido o mal formado")
		return
	}

	if strings.TrimSpace(input.Nombre) == "" {
		httputil.WriteError(w, http.StatusUnprocessableEntity, "VALIDATION_ERROR", "El campo 'nombre' no puede estar vacío")
		return
	}

	cat, err := h.repo.UpdateCategoria(r.Context(), id, input)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			httputil.WriteError(w, http.StatusNotFound, "NOT_FOUND", "La categoría a actualizar no existe")
			return
		}
		httputil.WriteError(w, http.StatusInternalServerError, "INTERNAL_SERVER_ERROR", err.Error())
		return
	}

	httputil.WriteSuccess(w, http.StatusOK, cat)
}

func (h *Handler) DeleteCategoria(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if strings.TrimSpace(id) == "" {
		httputil.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "El ID de la categoría es requerido")
		return
	}

	if err := h.repo.DeleteCategoria(r.Context(), id); err != nil {
		if errors.Is(err, ErrNotFound) {
			httputil.WriteError(w, http.StatusNotFound, "NOT_FOUND", "La categoría a eliminar no existe")
			return
		}
		httputil.WriteError(w, http.StatusInternalServerError, "INTERNAL_SERVER_ERROR", err.Error())
		return
	}

	httputil.WriteSuccess(w, http.StatusOK, map[string]string{
		"message": "Categoría eliminada correctamente",
	})
}

func (h *Handler) RegisterRoutes(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/v1/menu/categorias", h.ListCategorias)
	mux.HandleFunc("GET /api/v1/menu/categorias/{id}", h.GetCategoria)
	mux.HandleFunc("POST /api/v1/menu/categorias", h.CreateCategoria)
	mux.HandleFunc("PUT /api/v1/menu/categorias/{id}", h.UpdateCategoria)
	mux.HandleFunc("DELETE /api/v1/menu/categorias/{id}", h.DeleteCategoria)
}
