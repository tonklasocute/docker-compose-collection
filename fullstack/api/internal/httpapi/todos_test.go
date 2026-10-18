package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/tonklasocute/docker-compose-collection/fullstack/api/internal/store"
)

// fakeStore is an in-memory TodoStore.
type fakeStore struct {
	mu     sync.Mutex
	nextID int64
	todos  map[int64]store.Todo
}

func newFakeStore() *fakeStore { return &fakeStore{nextID: 1, todos: map[int64]store.Todo{}} }

func (f *fakeStore) List(_ context.Context, limit, offset int) ([]store.Todo, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	out := []store.Todo{}
	for id := f.nextID - 1; id > 0; id-- {
		if t, ok := f.todos[id]; ok {
			out = append(out, t)
		}
	}
	if offset > len(out) {
		return []store.Todo{}, nil
	}
	out = out[offset:]
	if len(out) > limit {
		out = out[:limit]
	}
	return out, nil
}

func (f *fakeStore) Get(_ context.Context, id int64) (store.Todo, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	t, ok := f.todos[id]
	if !ok {
		return t, store.ErrNotFound
	}
	return t, nil
}

func (f *fakeStore) Create(_ context.Context, title string, done bool) (store.Todo, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	now := time.Now()
	t := store.Todo{ID: f.nextID, Title: title, Done: done, CreatedAt: now, UpdatedAt: now}
	f.todos[t.ID] = t
	f.nextID++
	return t, nil
}

func (f *fakeStore) Update(_ context.Context, id int64, p store.TodoPatch) (store.Todo, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	t, ok := f.todos[id]
	if !ok {
		return t, store.ErrNotFound
	}
	if p.Title != nil {
		t.Title = *p.Title
	}
	if p.Done != nil {
		t.Done = *p.Done
	}
	f.todos[id] = t
	return t, nil
}

func (f *fakeStore) Delete(_ context.Context, id int64) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	if _, ok := f.todos[id]; !ok {
		return store.ErrNotFound
	}
	delete(f.todos, id)
	return nil
}

type fakePinger struct{ err error }

func (p fakePinger) Ping(context.Context) error { return p.err }

func newTestServer(db Pinger) (http.Handler, *fakeStore) {
	fs := newFakeStore()
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	return New(fs, db, logger), fs
}

func do(t *testing.T, h http.Handler, method, path, body string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(method, path, strings.NewReader(body))
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	return rec
}

func TestHealth(t *testing.T) {
	h, _ := newTestServer(fakePinger{})
	if rec := do(t, h, "GET", "/health", ""); rec.Code != http.StatusOK {
		t.Fatalf("healthy db: got %d", rec.Code)
	}
	h, _ = newTestServer(fakePinger{err: errors.New("connection refused")})
	if rec := do(t, h, "GET", "/health", ""); rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("db down: got %d, want 503", rec.Code)
	}
}

func TestTodoLifecycle(t *testing.T) {
	h, _ := newTestServer(fakePinger{})

	rec := do(t, h, "POST", "/api/v1/todos", `{"title":"  write tests  "}`)
	if rec.Code != http.StatusCreated {
		t.Fatalf("create: got %d %s", rec.Code, rec.Body)
	}
	if loc := rec.Header().Get("Location"); loc != "/api/v1/todos/1" {
		t.Fatalf("Location = %q", loc)
	}
	var created store.Todo
	_ = json.Unmarshal(rec.Body.Bytes(), &created)
	if created.Title != "write tests" {
		t.Fatalf("title not trimmed: %q", created.Title)
	}

	rec = do(t, h, "PATCH", "/api/v1/todos/1", `{"done":true}`)
	var updated store.Todo
	_ = json.Unmarshal(rec.Body.Bytes(), &updated)
	if rec.Code != http.StatusOK || !updated.Done || updated.Title != "write tests" {
		t.Fatalf("patch: got %d %+v", rec.Code, updated)
	}

	rec = do(t, h, "GET", "/api/v1/todos", "")
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), `"write tests"`) {
		t.Fatalf("list: got %d %s", rec.Code, rec.Body)
	}

	if rec = do(t, h, "DELETE", "/api/v1/todos/1", ""); rec.Code != http.StatusNoContent {
		t.Fatalf("delete: got %d", rec.Code)
	}
	if rec = do(t, h, "GET", "/api/v1/todos/1", ""); rec.Code != http.StatusNotFound {
		t.Fatalf("get after delete: got %d", rec.Code)
	}
}

func TestValidation(t *testing.T) {
	h, _ := newTestServer(fakePinger{})
	cases := []struct {
		name, method, path, body string
		want                     int
	}{
		{"empty title", "POST", "/api/v1/todos", `{"title":"   "}`, http.StatusUnprocessableEntity},
		{"title too long", "POST", "/api/v1/todos", `{"title":"` + strings.Repeat("x", 201) + `"}`, http.StatusUnprocessableEntity},
		{"unknown field", "POST", "/api/v1/todos", `{"title":"a","priority":1}`, http.StatusBadRequest},
		{"malformed json", "POST", "/api/v1/todos", `{"title":`, http.StatusBadRequest},
		{"bad id", "GET", "/api/v1/todos/abc", "", http.StatusBadRequest},
		{"zero id", "GET", "/api/v1/todos/0", "", http.StatusBadRequest},
		{"empty patch", "PATCH", "/api/v1/todos/1", `{}`, http.StatusBadRequest},
		{"limit too high", "GET", "/api/v1/todos?limit=1000", "", http.StatusBadRequest},
		{"missing todo", "DELETE", "/api/v1/todos/42", "", http.StatusNotFound},
		{"wrong method", "PUT", "/api/v1/todos/1", `{}`, http.StatusMethodNotAllowed},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if rec := do(t, h, tc.method, tc.path, tc.body); rec.Code != tc.want {
				t.Fatalf("got %d, want %d (%s)", rec.Code, tc.want, rec.Body)
			}
		})
	}
}

func TestListPagination(t *testing.T) {
	h, fs := newTestServer(fakePinger{})
	for _, title := range []string{"a", "b", "c"} {
		_, _ = fs.Create(context.Background(), title, false)
	}
	rec := do(t, h, "GET", "/api/v1/todos?limit=2&offset=1", "")
	var body struct {
		Items []store.Todo `json:"items"`
	}
	_ = json.Unmarshal(rec.Body.Bytes(), &body)
	if len(body.Items) != 2 || body.Items[0].Title != "b" || body.Items[1].Title != "a" {
		t.Fatalf("got %+v", body.Items)
	}
}
