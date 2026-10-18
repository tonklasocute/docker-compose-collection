// Liveness for the container healthcheck: answers without touching the API,
// so a slow database doesn't make Docker restart the web server.
export const dynamic = 'force-dynamic';

export function GET() {
  return Response.json({ status: 'ok' });
}
