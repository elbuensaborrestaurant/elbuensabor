package main

import (
	"encoding/json"
	"html/template"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"strings"
	"time"
)

type webServer struct {
	template *template.Template
	proxy    *httputil.ReverseProxy
}

func main() {
	apiURL := env("API_URL", "http://127.0.0.1:8080")
	target, err := url.Parse(apiURL)
	if err != nil || (target.Scheme != "http" && target.Scheme != "https") || target.Host == "" {
		log.Fatalf("API_URL debe ser una URL HTTP válida")
	}

	proxy := httputil.NewSingleHostReverseProxy(target)
	proxy.ErrorHandler = func(w http.ResponseWriter, r *http.Request, err error) {
		log.Printf("API upstream request failed: %v", err)
		writeError(w, http.StatusBadGateway, "API_UNAVAILABLE", "No se pudo conectar con la API Restaurant.")
	}

	page, err := template.ParseFiles("templates/index.html")
	if err != nil {
		log.Fatalf("No se pudo cargar la plantilla: %v", err)
	}
	server := &webServer{template: page, proxy: proxy}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /", server.index)
	mux.Handle("GET /static/", http.StripPrefix("/static/", http.FileServer(http.Dir("static"))))
	mux.Handle("GET /api/", proxy)
	mux.Handle("POST /api/", proxy)
	mux.Handle("PUT /api/", proxy)
	mux.Handle("DELETE /api/", proxy)
	mux.Handle("GET /health", proxy)

	address := env("WEB_ADDR", "127.0.0.1:5502")
	httpServer := &http.Server{
		Addr:              address,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}
	log.Printf("WEB_Go disponible en http://%s (API: %s)", address, target.Redacted())
	log.Fatal(httpServer.ListenAndServe())
}

func (server *webServer) index(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	if err := server.template.Execute(w, nil); err != nil {
		log.Printf("No se pudo renderizar el panel: %v", err)
	}
}

func writeError(w http.ResponseWriter, status int, code, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]any{
		"success": false,
		"error":   map[string]string{"code": code, "message": message},
	})
}

func env(key, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(key)); value != "" {
		return value
	}
	return fallback
}
