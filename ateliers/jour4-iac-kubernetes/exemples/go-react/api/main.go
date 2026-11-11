// API Formini (Go) — même contrat que les API Python, Node et Rust :
//   GET  /health      → "ok"
//   GET  /api/info    → identité du service + état de PostgreSQL et Redis
//   GET  /api/tasks   → liste des tâches (table partagée)
//   POST /api/tasks   → {"title": "..."} crée une tâche
//   GET  /api/hits    → incrémente et renvoie le compteur Redis de ce service
package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"runtime"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
)

const service = "api-go"

type task struct {
	ID        int       `json:"id"`
	Title     string    `json:"title"`
	Done      bool      `json:"done"`
	CreatedBy string    `json:"created_by"`
	CreatedAt time.Time `json:"created_at"`
}

type app struct {
	db  *pgxpool.Pool
	rdb *redis.Client
}

func main() {
	ctx := context.Background()

	db, err := pgxpool.New(ctx, os.Getenv("DATABASE_URL"))
	if err != nil {
		log.Fatalf("postgres : %v", err)
	}
	defer db.Close()

	opt, err := redis.ParseURL(os.Getenv("REDIS_URL"))
	if err != nil {
		log.Fatalf("redis : %v", err)
	}
	a := &app{db: db, rdb: redis.NewClient(opt)}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, _ *http.Request) { _, _ = w.Write([]byte("ok")) })
	mux.HandleFunc("GET /api/info", a.info)
	mux.HandleFunc("GET /api/tasks", a.listTasks)
	mux.HandleFunc("POST /api/tasks", a.createTask)
	mux.HandleFunc("GET /api/hits", a.hits)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	srv := &http.Server{Addr: ":" + port, Handler: logging(mux), ReadHeaderTimeout: 5 * time.Second}
	log.Printf("%s en écoute sur :%s", service, port)
	log.Fatal(srv.ListenAndServe())
}

func (a *app) info(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
	defer cancel()
	pg, rd := "ok", "ok"
	if err := a.db.Ping(ctx); err != nil {
		pg = "erreur : " + err.Error()
	}
	if err := a.rdb.Ping(ctx).Err(); err != nil {
		rd = "erreur : " + err.Error()
	}
	host, _ := os.Hostname()
	writeJSON(w, http.StatusOK, map[string]string{
		"service": service, "language": "Go " + strings.TrimPrefix(runtime.Version(), "go"),
		"hostname": host, "postgres": pg, "redis": rd,
	})
}

func (a *app) listTasks(w http.ResponseWriter, r *http.Request) {
	rows, err := a.db.Query(r.Context(),
		"SELECT id, title, done, created_by, created_at FROM tasks ORDER BY id DESC LIMIT 50")
	if err != nil {
		writeErr(w, err)
		return
	}
	defer rows.Close()
	tasks := []task{}
	for rows.Next() {
		var t task
		if err := rows.Scan(&t.ID, &t.Title, &t.Done, &t.CreatedBy, &t.CreatedAt); err != nil {
			writeErr(w, err)
			return
		}
		tasks = append(tasks, t)
	}
	writeJSON(w, http.StatusOK, tasks)
}

func (a *app) createTask(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Title string `json:"title"`
	}
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil || strings.TrimSpace(in.Title) == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "title requis"})
		return
	}
	var t task
	err := a.db.QueryRow(r.Context(),
		"INSERT INTO tasks (title, created_by) VALUES ($1, $2) RETURNING id, title, done, created_by, created_at",
		strings.TrimSpace(in.Title), service).Scan(&t.ID, &t.Title, &t.Done, &t.CreatedBy, &t.CreatedAt)
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, t)
}

func (a *app) hits(w http.ResponseWriter, r *http.Request) {
	n, err := a.rdb.Incr(r.Context(), "hits:"+service).Result()
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"service": service, "hits": n})
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func writeErr(w http.ResponseWriter, err error) {
	log.Printf("erreur : %v", err)
	writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
}

func logging(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		log.Printf("%s %s %s", r.Method, r.URL.Path, time.Since(start).Round(time.Millisecond))
	})
}
