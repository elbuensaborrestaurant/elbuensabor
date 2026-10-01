// Package config carga la configuración de la API desde variables de entorno.
package config

import (
	"os"
	"strconv"
	"time"
)

// Config agrupa todos los parámetros necesarios para arrancar la API.
type Config struct {
	AppEnv   string
	LogLevel string

	DBHost     string
	DBPort     string
	DBName     string
	DBUser     string
	DBPassword string
	DBPoolMax  int32
	DBPoolMin  int32

	ServerHost         string
	ServerPort         string
	ServerReadTimeout  time.Duration
	ServerWriteTimeout time.Duration
	ServerIdleTimeout  time.Duration

	JWTSecret    string
	JWTExpiry    time.Duration
	JWTPinExpiry time.Duration
}

// Load construye la configuración leyendo variables de entorno, con valores
// por defecto razonables para desarrollo local.
func Load() Config {
	return Config{
		AppEnv:   getEnv("APP_ENV", "development"),
		LogLevel: getEnv("LOG_LEVEL", "info"),

		DBHost:     getEnv("DB_HOST", "localhost"),
		DBPort:     getEnv("DB_PORT", "5432"),
		DBName:     getEnv("DB_NAME", "elbuensabor"),
		DBUser:     getEnv("DB_USER", "api_user"),
		DBPassword: getEnv("DB_PASSWORD", ""),
		DBPoolMax:  getEnvInt32("DB_POOL_MAX", 10),
		DBPoolMin:  getEnvInt32("DB_POOL_MIN", 2),

		ServerHost:         getEnv("SERVER_HOST", "0.0.0.0"),
		ServerPort:         getEnv("SERVER_PORT", "8080"),
		ServerReadTimeout:  getEnvDuration("SERVER_READ_TIMEOUT", 15*time.Second),
		ServerWriteTimeout: getEnvDuration("SERVER_WRITE_TIMEOUT", 15*time.Second),
		ServerIdleTimeout:  getEnvDuration("SERVER_IDLE_TIMEOUT", 60*time.Second),

		JWTSecret:    getEnv("JWT_SECRET", ""),
		JWTExpiry:    getEnvDuration("JWT_EXPIRY", 8*time.Hour),
		JWTPinExpiry: getEnvDuration("JWT_PIN_EXPIRY", 2*time.Hour),
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func getEnvInt32(key string, fallback int32) int32 {
	v := os.Getenv(key)
	if v == "" {
		return fallback
	}
	out, err := strconv.ParseInt(v, 10, 32)
	if err != nil {
		return fallback
	}
	return int32(out)
}

func getEnvDuration(key string, fallback time.Duration) time.Duration {
	v := os.Getenv(key)
	if v == "" {
		return fallback
	}
	d, err := time.ParseDuration(v)
	if err != nil {
		return fallback
	}
	return d
}
