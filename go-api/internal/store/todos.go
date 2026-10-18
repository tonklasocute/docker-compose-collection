// Package store holds the PostgreSQL queries. The schema lives in
// ../../migrations and is applied by the migrate service before the API starts.
package store

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var ErrNotFound = errors.New("not found")

type Todo struct {
	ID        int64     `json:"id"`
	Title     string    `json:"title"`
	Done      bool      `json:"done"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// TodoPatch holds optional fields; nil means "leave unchanged".
type TodoPatch struct {
	Title *string
	Done  *bool
}

type Todos struct {
	db *pgxpool.Pool
}

func NewTodos(db *pgxpool.Pool) *Todos { return &Todos{db: db} }

const columns = "id, title, done, created_at, updated_at"

func scan(row pgx.Row) (Todo, error) {
	var t Todo
	err := row.Scan(&t.ID, &t.Title, &t.Done, &t.CreatedAt, &t.UpdatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return t, ErrNotFound
	}
	return t, err
}

func (s *Todos) List(ctx context.Context, limit, offset int) ([]Todo, error) {
	rows, err := s.db.Query(ctx,
		"SELECT "+columns+" FROM todos ORDER BY id DESC LIMIT $1 OFFSET $2", limit, offset)
	if err != nil {
		return nil, err
	}
	return pgx.CollectRows(rows, func(r pgx.CollectableRow) (Todo, error) { return scan(r) })
}

func (s *Todos) Get(ctx context.Context, id int64) (Todo, error) {
	return scan(s.db.QueryRow(ctx, "SELECT "+columns+" FROM todos WHERE id = $1", id))
}

func (s *Todos) Create(ctx context.Context, title string, done bool) (Todo, error) {
	return scan(s.db.QueryRow(ctx,
		"INSERT INTO todos (title, done) VALUES ($1, $2) RETURNING "+columns, title, done))
}

func (s *Todos) Update(ctx context.Context, id int64, p TodoPatch) (Todo, error) {
	return scan(s.db.QueryRow(ctx, `
		UPDATE todos
		   SET title = COALESCE($2, title),
		       done = COALESCE($3, done),
		       updated_at = now()
		 WHERE id = $1
		RETURNING `+columns, id, p.Title, p.Done))
}

func (s *Todos) Delete(ctx context.Context, id int64) error {
	tag, err := s.db.Exec(ctx, "DELETE FROM todos WHERE id = $1", id)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}
