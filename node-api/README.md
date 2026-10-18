# NestJS API + PostgreSQL + Redis

A NestJS 12 REST API with PostgreSQL for storage and a Redis **cache-aside** layer, built from one Dockerfile into two targets:
- **`prod`**: compiled JS on `node:24-alpine`, non-root, npm stripped out, read-only root filesystem.
- **`dev`**: `nest start --watch` on your bind-mounted `src/`, so saving a file recompiles and restarts the app.

## Quick start

```bash
cp .env.example .env      # set the passwords
docker compose up -d --build --wait
make test                 # smoke test: CRUD, cache HIT/MISS, validation, hardening, watch mode
```

```bash
curl -s localhost:3000/health
curl -s -X POST localhost:3000/api/v1/notes -H 'Content-Type: application/json' -d '{"title":"hi"}'
curl -si localhost:3000/api/v1/notes/1 | grep -i x-cache     # MISS, then HIT
```

Watch mode: `make dev` starts `api-dev` on http://localhost:3001. Edit anything in `src/`.

## Services

| Service    | Image / build                         | Host port        | Profile   |
|------------|---------------------------------------|------------------|-----------|
| `postgres` | `postgres:16.15-alpine3.24`           | `127.0.0.1:5432` | (default) |
| `redis`    | `redis:7.4.11-alpine3.21` (cache: LRU, no persistence) | `127.0.0.1:6379` | (default) |
| `api`      | `Dockerfile`, target `prod`           | `127.0.0.1:3000` | (default) |
| `api-dev`  | `Dockerfile`, target `dev` + `./src` bind mount (read-only) | `127.0.0.1:3001` | `dev` |

## API

| Method   | Path                  | Body / query                          | Notes |
|----------|-----------------------|---------------------------------------|-------|
| `GET`    | `/health`             | –                                     | `200 {"status":"ok","db":"ok","redis":"ok","version":"1.0.0"}`, or `503` |
| `GET`    | `/api/v1/notes`       | `?limit=1..100&offset=0`              | newest first |
| `POST`   | `/api/v1/notes`       | `{"title":"...", "body":"..."}`       | `201`. The title is trimmed and must be 1–200 characters |
| `GET`    | `/api/v1/notes/:id`   | –                                     | cached in Redis; `X-Cache: HIT` or `MISS` |
| `PATCH`  | `/api/v1/notes/:id`   | `{"title"?, "body"?}`                 | invalidates the cache entry |
| `DELETE` | `/api/v1/notes/:id`   | –                                     | `204`, invalidates the cache entry |

Validation uses a global `ValidationPipe` with `whitelist` and `forbidNonWhitelisted`. Unknown fields, bad ids and invalid values return `400` with Nest's standard error body.

## How it's built

| Stage   | Base                       | Purpose |
|---------|----------------------------|---------|
| `deps`  | `node:24.22.0-alpine3.24`  | `npm ci` with a BuildKit cache mount, as user `node` |
| `dev`   | `deps`                     | `npm run start:dev`; `TSC_WATCHFILE=DynamicPriorityPolling` so watch mode works on Docker Desktop bind mounts |
| `test`  | `deps`                     | `tsc --noEmit` + vitest (`make unit-test`) |
| `build` | `deps`                     | `nest build`, then `npm prune --omit=dev` |
| `prod`  | `node:24.22.0-alpine3.24`  | `dist/` + production `node_modules` only, npm/npx/corepack/yarn removed, root-owned files, `USER node` |

**Size**: `prod` is **~207 MB uncompressed / 69 MB compressed** (the registry download). Of that, 126 MB is the Node.js binary, 59 MB is production `node_modules` and the app (`dist/`) is 52 KB. Docker 29's `docker image ls` shows ~312 MB "disk usage", which counts both the compressed and unpacked copies. The Redis client is `@redis/client` rather than the `redis` meta-package, which saves the unused search/JSON/bloom/time-series modules.

**Hardening** in `compose.yaml`: `read_only: true` (+ a `tmpfs` for `/tmp`), `cap_drop: [ALL]`, `no-new-privileges`, and 1 CPU / 256 MB limits. The smoke test checks the user, the read-only root filesystem and dropped capabilities, and that `npm` is gone.

## Environment variables

| Variable            | Default      | Description |
|---------------------|--------------|-------------|
| `POSTGRES_USER`     | `app`        | Database owner, used by the API |
| `POSTGRES_PASSWORD` | **required** | URL-safe characters (goes into `DATABASE_URL`) |
| `POSTGRES_DB`       | `app`        | Database name |
| `POSTGRES_PORT`     | `5432`       | Host port |
| `REDIS_PASSWORD`    | **required** | Redis `requirepass` |
| `REDIS_PORT`        | `6379`       | Host port |
| `CACHE_TTL_SECONDS` | `60`         | TTL of cached notes |
| `API_PORT`          | `3000`       | Host port of `api` |
| `API_DEV_PORT`      | `3001`       | Host port of `api-dev` |
| `API_VERSION`       | `1.0.0`      | Reported by `/health` |

The app reads `DATABASE_URL`, `REDIS_URL`, `CACHE_TTL_SECONDS`, `APP_VERSION` and `PORT`. Compose builds the URLs from the values above.

## Default credentials

PostgreSQL `app` / `change-me-postgres` (database `app`). Redis password `change-me-redis`. The API has no auth; add a guard for your use case.

## Connecting

- **From the host**: API on http://localhost:3000, `make psql`, `make redis-cli`.
- **From another container on the `backend` network**: `http://api:3000`.
- **From another compose project**: join `node-api_backend` as an external network.

## Schema

[`init/01-schema.sql`](init/01-schema.sql) creates the `notes` table the first time the Postgres volume is created. For a schema that evolves, use a migration tool (node-pg-migrate, Prisma Migrate…) run as a one-shot service before the API. [`../go-api`](../go-api) shows that pattern with `service_completed_successfully`.

## Local development without Docker

```bash
npm ci
npm test               # vitest
npm run typecheck
DATABASE_URL=postgres://app:change-me-postgres@localhost:5432/app \
REDIS_URL=redis://:change-me-redis@localhost:6379 npm run start:dev
```

## Reset data

```bash
make reset        # asks for confirmation, then: docker compose down -v
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| `relation "notes" does not exist` | The Postgres volume predates `init/`. Run `make reset`. |
| `NOAUTH` / `WRONGPASS` from Redis | `REDIS_PASSWORD` changed. Run `docker compose up -d` to recreate both containers. |
| Watch mode doesn't pick up changes | Check `make logs s=api-dev` for TypeScript errors. Polling is on via `TSC_WATCHFILE`. |
| `npm: not found` inside `api` | Intentional. Use `api-dev` or `docker build --target build` for npm. |
| `EROFS: read-only file system` | The prod container is read-only. Write to `/tmp` (tmpfs) or a volume. |

## Files

```
node-api/
├── src/
│   ├── main.ts                    # bootstrap: JSON logs in prod, validation, shutdown hooks
│   ├── app.module.ts
│   ├── database/database.module.ts  # pg Pool + Redis client providers, closed on shutdown
│   ├── health/health.controller.ts
│   ├── notes/                     # controller, service (cache-aside), DTOs, unit tests
│   └── version.ts
├── init/01-schema.sql
├── Dockerfile, .dockerignore, package.json, package-lock.json, tsconfig*.json, nest-cli.json, vitest.config.ts
├── compose.yaml, .env.example
├── Makefile                       # up, dev, down, logs, ps, reset, test, unit-test, psql, redis-cli
└── smoke-test.sh
```
