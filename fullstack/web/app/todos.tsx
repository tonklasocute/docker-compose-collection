'use client';

import { useState, type FormEvent } from 'react';
import type { Todo } from '@/lib/api';

// Relative URL: the browser talks to nginx, which routes /api/ to the Go API
const API = '/api/v1/todos';

async function call<T>(url: string, init?: RequestInit): Promise<T> {
  const res = await fetch(url, { ...init, headers: { 'Content-Type': 'application/json' } });
  if (!res.ok) {
    const body = (await res.json().catch(() => null)) as { error?: string } | null;
    throw new Error(body?.error ?? `The API answered HTTP ${res.status}.`);
  }
  return (res.status === 204 ? undefined : await res.json()) as T;
}

export function Todos({ initial, disabled }: { initial: Todo[]; disabled: boolean }) {
  const [todos, setTodos] = useState(initial);
  const [title, setTitle] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function run(action: () => Promise<void>) {
    setBusy(true);
    setError(null);
    try {
      await action();
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setBusy(false);
    }
  }

  function add(e: FormEvent) {
    e.preventDefault();
    if (!title.trim()) return;
    void run(async () => {
      const todo = await call<Todo>(API, { method: 'POST', body: JSON.stringify({ title }) });
      setTodos((list) => [todo, ...list]);
      setTitle('');
    });
  }

  // Optimistic: tick the box immediately, roll back if the API says no
  const toggle = (todo: Todo) => {
    const flip = (done: boolean) =>
      setTodos((list) => list.map((t) => (t.id === todo.id ? { ...t, done } : t)));
    flip(!todo.done);
    return run(async () => {
      try {
        await call<Todo>(`${API}/${todo.id}`, {
          method: 'PATCH',
          body: JSON.stringify({ done: !todo.done }),
        });
      } catch (err) {
        flip(todo.done);
        throw err;
      }
    });
  };

  const remove = (todo: Todo) =>
    run(async () => {
      await call<void>(`${API}/${todo.id}`, { method: 'DELETE' });
      setTodos((list) => list.filter((t) => t.id !== todo.id));
    });

  return (
    <>
      <form className="add" onSubmit={add}>
        <label htmlFor="new-todo" className="visually-hidden">
          New todo
        </label>
        <input
          id="new-todo"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          placeholder="What needs doing?"
          maxLength={200}
          disabled={disabled}
          autoComplete="off"
        />
        <button type="submit" disabled={disabled || busy || !title.trim()}>
          Add todo
        </button>
      </form>

      {error && (
        <p className="error" role="alert">
          {error}
        </p>
      )}

      {todos.length === 0 ? (
        <p className="empty">No todos yet. Add one and it will take the same route as this page.</p>
      ) : (
        <ul className="list">
          {todos.map((todo) => (
            <li key={todo.id} className="item" data-done={todo.done}>
              <input
                type="checkbox"
                id={`todo-${todo.id}`}
                checked={todo.done}
                onChange={() => toggle(todo)}
                disabled={busy}
              />
              <label htmlFor={`todo-${todo.id}`}>{todo.title}</label>
              <button type="button" className="delete" onClick={() => remove(todo)} disabled={busy}>
                Delete<span className="visually-hidden"> “{todo.title}”</span>
              </button>
            </li>
          ))}
        </ul>
      )}
    </>
  );
}
