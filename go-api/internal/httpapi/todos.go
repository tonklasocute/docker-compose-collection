package httpapi

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"strings"

	"github.com/tonklasocute/docker-compose-collection/go-api/internal/store"
)

const (
	maxBodyBytes = 1 << 20
	maxTitleLen  = 200
	defaultLimit = 50
	maxLimit     = 100
)

type createTodoRequest struct {
	Title string `json:"title"`
	Done  bool   `json:"done"`
}

type updateTodoRequest struct {
	Title *string `json:"title"`
	Done  *bool   `json:"done"`
}

func (s *server) listTodos(w http.ResponseWriter, r *http.Request) {
	limit, err := intParam(r, "limit", defaultLimit, 1, maxLimit)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	offset, err := intParam(r, "offset", 0, 0, 1<<31-1)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	todos, err := s.todos.List(r.Context(), limit, offset)
	if err != nil {
		s.internalError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": todos, "limit": limit, "offset": offset})
}

func (s *server) createTodo(w http.ResponseWriter, r *http.Request) {
	var req createTodoRequest
	if !decode(w, r, &req) {
		return
	}
	title, ok := validTitle(w, req.Title)
	if !ok {
		return
	}
	todo, err := s.todos.Create(r.Context(), title, req.Done)
	if err != nil {
		s.internalError(w, err)
		return
	}
	w.Header().Set("Location", "/api/v1/todos/"+strconv.FormatInt(todo.ID, 10))
	writeJSON(w, http.StatusCreated, todo)
}

func (s *server) getTodo(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	todo, err := s.todos.Get(r.Context(), id)
	s.respond(w, http.StatusOK, todo, err)
}

func (s *server) updateTodo(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	var req updateTodoRequest
	if !decode(w, r, &req) {
		return
	}
	if req.Title == nil && req.Done == nil {
		writeError(w, http.StatusBadRequest, "nothing to update: send title and/or done")
		return
	}
	if req.Title != nil {
		title, ok := validTitle(w, *req.Title)
		if !ok {
			return
		}
		req.Title = &title
	}
	todo, err := s.todos.Update(r.Context(), id, store.TodoPatch{Title: req.Title, Done: req.Done})
	s.respond(w, http.StatusOK, todo, err)
}

func (s *server) deleteTodo(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	if err := s.todos.Delete(r.Context(), id); err != nil {
		s.respond(w, 0, nil, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// respond maps store errors to HTTP status codes.
func (s *server) respond(w http.ResponseWriter, status int, v any, err error) {
	switch {
	case errors.Is(err, store.ErrNotFound):
		writeError(w, http.StatusNotFound, "todo not found")
	case err != nil:
		s.internalError(w, err)
	default:
		writeJSON(w, status, v)
	}
}

func (s *server) internalError(w http.ResponseWriter, err error) {
	s.logger.Error("internal error", "err", err)
	writeError(w, http.StatusInternalServerError, "internal error")
}

func decode(w http.ResponseWriter, r *http.Request, dst any) bool {
	dec := json.NewDecoder(http.MaxBytesReader(w, r.Body, maxBodyBytes))
	dec.DisallowUnknownFields()
	if err := dec.Decode(dst); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body: "+err.Error())
		return false
	}
	return true
}

func validTitle(w http.ResponseWriter, title string) (string, bool) {
	title = strings.TrimSpace(title)
	switch {
	case title == "":
		writeError(w, http.StatusUnprocessableEntity, "title is required")
	case len([]rune(title)) > maxTitleLen:
		writeError(w, http.StatusUnprocessableEntity, "title must be at most 200 characters")
	default:
		return title, true
	}
	return "", false
}

func pathID(w http.ResponseWriter, r *http.Request) (int64, bool) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil || id < 1 {
		writeError(w, http.StatusBadRequest, "id must be a positive integer")
		return 0, false
	}
	return id, true
}

func intParam(r *http.Request, name string, def, lo, hi int) (int, error) {
	raw := r.URL.Query().Get(name)
	if raw == "" {
		return def, nil
	}
	n, err := strconv.Atoi(raw)
	if err != nil || n < lo || n > hi {
		return 0, errors.New(name + " must be an integer between " + strconv.Itoa(lo) + " and " + strconv.Itoa(hi))
	}
	return n, nil
}
