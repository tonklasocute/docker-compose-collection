export interface Stop {
  id: 'browser' | 'nginx' | 'next' | 'api' | 'postgres';
  name: string;
  ok: boolean;
  detail: string;
}

/**
 * The request path drawn as a transit line. Each segment takes the colour of
 * the service it leads into; a stop that failed is drawn hollow.
 */
export function RouteMap({ stops }: { stops: Stop[] }) {
  return (
    <ol className="route" aria-label="Request path">
      {stops.map((stop) => (
        <li key={stop.id} className="stop" data-hop={stop.id} data-status={stop.ok ? 'ok' : 'down'}>
          <span className="station" aria-hidden="true" />
          <span className="stop-name">{stop.name}</span>
          <span className="stop-detail">
            <span className="visually-hidden">{stop.ok ? 'OK: ' : 'Problem: '}</span>
            {stop.detail}
          </span>
        </li>
      ))}
    </ol>
  );
}
