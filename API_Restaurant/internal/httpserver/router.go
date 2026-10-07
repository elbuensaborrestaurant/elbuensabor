// Package httpserver ensambla el router raiz y los middlewares globales.
package httpserver

import (
	"log/slog"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/saborurbano/api_restaurant/internal/auth"
	"github.com/saborurbano/api_restaurant/internal/configmod"
	"github.com/saborurbano/api_restaurant/internal/menu"
)

// NewRouter construye el mux raiz con las rutas base de la API.
func NewRouter(pool *pgxpool.Pool, sessionExpiry time.Duration) http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		if err := pool.Ping(r.Context()); err != nil {
			WriteError(w, http.StatusServiceUnavailable, "DB_UNAVAILABLE", err.Error())
			return
		}
		WriteSuccess(w, http.StatusOK, map[string]string{"status": "ok"})
	})

	mux.HandleFunc("GET /api/v1/version", func(w http.ResponseWriter, r *http.Request) {
		WriteSuccess(w, http.StatusOK, map[string]string{"version": "0.1.0"})
	})

	// Registro de modulos de dominio
	configRepo := configmod.NewRepository(pool)
	configHandler := configmod.NewHandler(configRepo)
	configHandler.RegisterRoutes(mux)

	authHandler := auth.NewHandler(pool, sessionExpiry)
	authHandler.RegisterRoutes(mux)

	menuRepo := menu.NewRepository(pool)
	menuHandler := menu.NewHandler(menuRepo)
	menuHandler.RegisterRoutes(mux)

	return withLogging(mux)
}

func withLogging(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		slog.Info("request",
			"method", r.Method,
			"path", r.URL.Path,
			"duration_ms", time.Since(start).Milliseconds(),
		)
	})
}
