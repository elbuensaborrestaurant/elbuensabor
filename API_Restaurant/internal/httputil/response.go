package httputil

import (
	"encoding/json"
	"net/http"
)

type envelope struct {
	Success bool        `json:"success"`
	Data    interface{} `json:"data,omitempty"`
	Meta    interface{} `json:"meta,omitempty"`
	Error   *apiError   `json:"error,omitempty"`
}

type apiError struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

// WriteSuccess responde 200/201/etc. con el payload en "data".
func WriteSuccess(w http.ResponseWriter, status int, data interface{}) {
	writeJSON(w, status, envelope{Success: true, Data: data})
}

// WritePaginated responde un listado incluyendo metadatos de paginacion.
func WritePaginated(w http.ResponseWriter, status int, data interface{}, meta interface{}) {
	writeJSON(w, status, envelope{Success: true, Data: data, Meta: meta})
}

// WriteError responde un error con el codigo y mensaje indicados.
func WriteError(w http.ResponseWriter, status int, code, message string) {
	writeJSON(w, status, envelope{Success: false, Error: &apiError{Code: code, Message: message}})
}

func writeJSON(w http.ResponseWriter, status int, body envelope) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}
