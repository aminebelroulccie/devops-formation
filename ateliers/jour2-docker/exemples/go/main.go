// Formini Hello — service HTTP minimal en Go (bibliothèque standard uniquement).
// Routes : GET /  → JSON de bienvenue, GET /health → 200 "ok".
package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"time"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/health", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]string{
			"service":  "formini-hello-go",
			"message":  "Bonjour Formini",
			"path":     r.URL.Path,
			"hostname": hostname(),
		})
	})

	srv := &http.Server{
		Addr:              ":" + port,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}
	log.Printf("formini-hello-go en écoute sur :%s", port)
	log.Fatal(srv.ListenAndServe())
}

func hostname() string {
	h, err := os.Hostname()
	if err != nil {
		return "inconnu"
	}
	return h
}
