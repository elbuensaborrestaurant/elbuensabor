// Package httpserver define el envelope de respuestas estandar de la API
// (ver seccion 4 de docs/api_manual.md).
package httpserver

import (
	"net/http"

	"github.com/saborurbano/api_restaurant/internal/httputil"
)

// Reexporta funciones para compatibilidad dentro de httpserver
var (
	WriteSuccess   = httputil.WriteSuccess
	WritePaginated = httputil.WritePaginated
	WriteError     = httputil.WriteError
)

type EnvelopeFunc func(w http.ResponseWriter, status int, data interface{})
