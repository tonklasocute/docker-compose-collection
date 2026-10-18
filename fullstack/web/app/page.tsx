import { headers } from 'next/headers';
import { snapshot } from '@/lib/api';
import { RouteMap, type Stop } from './route-map';
import { Todos } from './todos';

// Render on every request: the point of the page is to show the live path.
export const dynamic = 'force-dynamic';

const ms = (n: number) => `${Math.max(1, Math.round(n))} ms`;

export default async function Page() {
  const started = performance.now();
  const viaNginx = (await headers()).get('x-proxied-by') === 'nginx';
  const data = await snapshot();
  if (data.error) console.error('[page] API check failed:', data.error);
  const renderMs = performance.now() - started;

  const stops: Stop[] = [
    { id: 'browser', name: 'Your browser', ok: true, detail: 'asked for this page' },
    {
      id: 'nginx',
      name: 'nginx',
      ok: viaNginx,
      detail: viaNginx ? 'forwarded it to Next.js' : 'was skipped: open the nginx port instead',
    },
    { id: 'next', name: 'Next.js', ok: true, detail: `rendered it on the server in ${ms(renderMs)}` },
    {
      id: 'api',
      name: 'Go API',
      ok: data.apiOk,
      detail: data.apiOk ? `v${data.version} answered in ${ms(data.apiMs)}` : 'did not answer',
    },
    {
      id: 'postgres',
      name: 'PostgreSQL',
      ok: data.dbOk,
      detail: data.dbOk
        ? `holds ${data.todos.length} ${data.todos.length === 1 ? 'todo' : 'todos'}`
        : data.apiOk
          ? 'is not reachable from the API'
          : 'can’t be checked without the API',
    },
  ];

  let summary =
    'This page travelled through the whole stack to reach you. Each stop below is live: reload and the numbers change.';
  if (!viaNginx) summary = 'You reached Next.js directly. Open the nginx port to see the full path.';
  if (!data.apiOk)
    summary = 'The Go API didn’t answer, so this page stopped at Next.js. Run “docker compose logs api” to see why.';
  else if (!data.dbOk)
    summary = 'The Go API is up but can’t reach PostgreSQL. Run “docker compose logs postgres” to see why.';

  return (
    <main className="page">
      <header className="intro">
        <h1>Every service, one request</h1>
        <p>{summary}</p>
      </header>

      <RouteMap stops={stops} />

      <section className="todos" aria-labelledby="todos-heading">
        <h2 id="todos-heading">Todos</h2>
        <p className="hint">
          Changes here go from your browser through nginx to the Go API and into PostgreSQL.
        </p>
        <Todos initial={data.todos} disabled={!data.apiOk} />
      </section>
    </main>
  );
}
