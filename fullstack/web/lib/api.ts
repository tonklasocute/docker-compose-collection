import 'server-only';

// Server-side calls go straight to the API over the compose network; the
// browser goes through nginx (/api/...). Same API, two routes to it.
const API = process.env.API_INTERNAL_URL ?? 'http://api:8080';

export interface Todo {
  id: number;
  title: string;
  done: boolean;
  created_at: string;
  updated_at: string;
}

export interface Snapshot {
  apiOk: boolean;
  dbOk: boolean;
  version?: string;
  apiMs: number;
  todos: Todo[];
  error?: string;
}

/** Everything the page shows, fetched in one pass and timed. */
export async function snapshot(): Promise<Snapshot> {
  const started = performance.now();
  try {
    const [health, list] = await Promise.all([
      fetch(`${API}/health`, { cache: 'no-store', signal: AbortSignal.timeout(3000) }),
      fetch(`${API}/api/v1/todos?limit=50`, { cache: 'no-store', signal: AbortSignal.timeout(3000) }),
    ]);
    const h = (await health.json()) as { status: string; db: string; version?: string };
    const todos = list.ok ? ((await list.json()) as { items: Todo[] }).items : [];
    return {
      apiOk: true,
      dbOk: health.ok && h.db === 'ok',
      version: h.version,
      apiMs: performance.now() - started,
      todos,
      error: health.ok ? undefined : h.db,
    };
  } catch (err) {
    return {
      apiOk: false,
      dbOk: false,
      apiMs: performance.now() - started,
      todos: [],
      error: err instanceof Error ? err.message : String(err),
    };
  }
}
