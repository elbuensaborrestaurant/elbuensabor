// Comando principal de la API REST "El Buen Sabor".
package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/joho/godotenv"

	"github.com/saborurbano/api_restaurant/internal/config"
	"github.com/saborurbano/api_restaurant/internal/httpserver"
	"github.com/saborurbano/api_restaurant/internal/platform/db"
)

func main() {
	// En produccion las variables se cargan via systemd EnvironmentFile;
	// en desarrollo se admite un archivo .env local.
	_ = godotenv.Load()

	cfg := config.Load()

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	pool, err := db.NewPool(ctx, cfg)
	if err != nil {
		slog.Error("no se pudo conectar a la base de datos", "error", err)
		os.Exit(1)
	}
	defer pool.Close()

	router := httpserver.NewRouter(pool)

	srv := &http.Server{
		Addr:         cfg.ServerHost + ":" + cfg.ServerPort,
		Handler:      router,
		ReadTimeout:  cfg.ServerReadTimeout,
		WriteTimeout: cfg.ServerWriteTimeout,
		IdleTimeout:  cfg.ServerIdleTimeout,
	}

	go func() {
		slog.Info("iniciando servidor HTTP", "addr", srv.Addr, "env", cfg.AppEnv)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			slog.Error("error del servidor HTTP", "error", err)
			os.Exit(1)
		}
	}()

	<-ctx.Done()
	slog.Info("apagando servidor...")

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		slog.Error("error durante el apagado", "error", err)
	}
}
