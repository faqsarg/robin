package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"robin/backend/internal/db"
)

// Set at build time via -ldflags, e.g.:
//
//	go build -ldflags "-X main.version=$(git rev-parse --short HEAD)"
var version = "dev"

func main() {
	port := getenv("PORT", "8080")
	dsn := buildDSN()

	database, err := db.Connect(dsn)
	if err != nil {
		log.Fatalf("connecting to database: %v", err)
	}
	defer database.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	if err := db.Migrate(ctx, database); err != nil {
		cancel()
		log.Fatalf("running migration/seed: %v", err)
	}
	cancel()

	mux := http.NewServeMux()

	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})

	mux.HandleFunc("GET /version", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"version": version})
	})

	mux.HandleFunc("GET /api/quote", func(w http.ResponseWriter, r *http.Request) {
		ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
		defer cancel()

		quote, err := db.RandomQuote(ctx, database)
		if err != nil {
			log.Printf("error fetching quote: %v", err)
			writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "could not fetch quote"})
			return
		}
		writeJSON(w, http.StatusOK, map[string]string{"quote": quote})
	})

	srv := &http.Server{
		Addr:              ":" + port,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}

	go func() {
		log.Printf("listening on :%s (version=%s)", port, version)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("server error: %v", err)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop

	log.Println("shutting down...")
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Printf("shutdown error: %v", err)
	}
}

func buildDSN() string {
	host := getenv("DB_HOST", "localhost")
	port := getenv("DB_PORT", "5432")
	user := getenv("DB_USER", "postgres")
	password := os.Getenv("DB_PASSWORD")
	name := getenv("DB_NAME", "postgres")
	sslmode := getenv("DB_SSLMODE", "disable")

	return fmt.Sprintf(
		"postgres://%s:%s@%s:%s/%s?sslmode=%s",
		user, password, host, port, name, sslmode,
	)
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}
