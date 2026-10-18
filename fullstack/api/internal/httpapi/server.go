// Package httpapi wires the HTTP routes, middleware and JSON helpers.
package httpapi

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"time"

	"github.com/tonklasocute/docker-compose-collection/fullstack/api/internal/store"
)

// Version is reported by /health. Overridden at build time with
// -ldflags "-X .../internal/httpapi.Version=..." (see the Dockerfile).
var Version = "dev"

// TodoStore is the subset of store.Todos the handlers need (a fake in tests).
type TodoStore interface {
	List(ctx context.Context, limit, offset int) ([]store.Todo, error)
	Get(ctx context.Context, id int64) (store.Todo, error)
	Create(ctx context.Context, title string, done bool) (store.Todo, error)
	Update(ctx context.Context, id int64, p store.TodoPatch) (store.Todo, error)
	Delete(ctx context.Context, id int64) error
}

// Pinger reports database reachability for /health.
type Pinger interface {
	Ping(ctx context.Context) error
}

type server struct {
	todos  TodoStore
	db     Pinger
	logger *slog.Logger
}

func New(todos TodoStore, db Pinger, logger *slog.Logger) http.Handler {
	s := &server{todos: todos, db: db, logger: logger}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", s.health)
	mux.HandleFunc("GET /api/v1/todos", s.listTodos)
	mux.HandleFunc("POST /api/v1/todos", s.createTodo)
	mux.HandleFunc("GET /api/v1/todos/{id}", s.getTodo)
	mux.HandleFunc("PATCH /api/v1/todos/{id}", s.updateTodo)
	mux.HandleFunc("DELETE /api/v1/todos/{id}", s.deleteTodo)
	return s.logRequests(mux)
}

func (s *server) health(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
	defer cancel()
	if err := s.db.Ping(ctx); err != nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"status": "unavailable", "db": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok", "db": "ok", "version": Version})
}

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (r *statusRecorder) WriteHeader(code int) {
	r.status = code
	r.ResponseWriter.WriteHeader(code)
}

func (s *server) logRequests(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		rec := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(rec, r)
		if r.URL.Path == "/health" && rec.status == http.StatusOK {
			return // healthchecks every few seconds would drown the log
		}
		s.logger.Info("request", "method", r.Method, "path", r.URL.Path,
			"status", rec.status, "duration_ms", time.Since(start).Milliseconds())
	})
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"error": msg})
}
