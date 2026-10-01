package configmod

import (
	"errors"
	"net/http"

	"github.com/saborurbano/api_restaurant/internal/httputil"
)

type Handler struct {
	repo *Repository
}

func NewHandler(repo *Repository) *Handler {
	return &Handler{repo: repo}
}

func (h *Handler) GetEstablecimiento(w http.ResponseWriter, r *http.Request) {
	est, err := h.repo.GetEstablecimiento(r.Context())
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			httputil.WriteError(w, http.StatusNotFound, "NOT_FOUND", "No se ha configurado la información del establecimiento")
			return
		}
		httputil.WriteError(w, http.StatusInternalServerError, "INTERNAL_SERVER_ERROR", err.Error())
		return
	}

	httputil.WriteSuccess(w, http.StatusOK, est)
}

func (h *Handler) RegisterRoutes(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/v1/config/establecimiento", h.GetEstablecimiento)
}
