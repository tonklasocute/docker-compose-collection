# Go REST API + PostgreSQL

A production-shaped Go service you can copy as a starting point:
- a small REST API (todos CRUD) on the standard library router and `pgx`,
- SQL migrations applied by a one-shot `migrate` container before the API starts,
- a **multi-stage build** into a **distroless, non-root** image of about 13 MB,
- a `dev` profile with **hot reload** via [air](https://github.com/air-verse/air).

## Quick start

```bash
cp .env.example .env      # set POSTGRES_PASSWORD
docker compose up -d --build --wait
make test                 # smoke test: CRUD, 404/422, hardening, hot reload if running
```

```bash
curl -s localhost:8080/health
curl -s -X POST localhost:8080/api/v1/todos -H 'Content-Type: application/json' -d '{"title":"ship it"}'
```

Hot reload: `make dev` starts `api-dev` on http://localhost:8081. Edit any `.go` file and it rebuilds in a second or two.

## Services

| Service    | Image / build                            | Host port        | Profile   |
|------------|------------------------------------------|------------------|-----------|
| `postgres` | `postgres:16.15-alpine3.24`              | `127.0.0.1:5432` | (default) |
| `migrate`  | `migrate/migrate:v4.20.1`                | – (runs once)    | (default) |
| `api`      | `Dockerfile`, target `final`             | `127.0.0.1:8080` | (default) |
| `api-dev`  | `Dockerfile`, target `dev` + bind mount  | `127.0.0.1:8081` | `dev`     |

Start order: `postgres` (healthy) → `migrate` (exits 0) → `api` (healthy). `depends_on` uses `service_healthy` and `service_completed_successfully`, so the API never starts against a missing schema.

## API

| Method   | Path                  | Body / query                       | Success |
|----------|-----------------------|------------------------------------|---------|
| `GET`    | `/health`             | –                                  | `200 {"status":"ok","db":"ok","version":"1.0.0"}`, or `503` if the DB is down |
| `GET`    | `/api/v1/todos`       | `?limit=1..100&offset=0`           | `200 {"items":[...],"limit":50,"offset":0}` |
| `POST`   | `/api/v1/todos`       | `{"title":"...", "done":false}`    | `201` + `Location` header |
| `GET`    | `/api/v1/todos/{id}`  | –                                  | `200` / `404` |
| `PATCH`  | `/api/v1/todos/{id}`  | `{"title"?: "...", "done"?: true}` | `200` / `404` |
| `DELETE` | `/api/v1/todos/{id}`  | –                                  | `204` / `404` |

Validation: titles are trimmed and must be 1–200 characters (`422`). Unknown JSON fields, malformed JSON and bodies over 1 MB return `400`. Errors are JSON: `{"error":"..."}`.

## Image

| Stage   | Base                                      | Purpose                                     |
|---------|-------------------------------------------|---------------------------------------------|
| `base`  | `golang:1.27.2-alpine3.24`                | modules downloaded once, BuildKit cache mounts |
| `dev`   | `base` + air                              | hot reload; source bind-mounted              |
| `test`  | `base`                                    | `go vet` + `go test` (`make unit-test`)      |
| `build` | `base`                                    | `CGO_ENABLED=0`, `-trimpath -ldflags "-s -w"`, version via `-X` |
| `final` | `gcr.io/distroless/static-debian13:nonroot` (pinned by digest) | binary only, `USER 65532:65532` (nonroot) |

**Size**: the `final` image is **~13 MB uncompressed** (10.6 MB static binary + distroless/static) and **5.2 MB compressed**, which is what a registry pull downloads. Docker 29's `docker image ls` reports 22.6 MB "disk usage" because its containerd store keeps both the compressed and the unpacked copy. The `dev` image is about 600 MB (full Go toolchain), but it is never shipped.

**Healthcheck without a shell**: distroless has no `curl`, `wget` or `sh`, so `/app/api healthcheck` makes the request itself and exits 0 or 1. The `Dockerfile` and `compose.yaml` both use it.

**Runtime hardening** in `compose.yaml`: `read_only: true`, `cap_drop: [ALL]`, `no-new-privileges`, plus 0.5 CPU and 128 MB limits. The smoke test checks the user, read-only root filesystem and dropped capabilities.

## Environment variables

| Variable            | Default      | Description                                         |
|---------------------|--------------|-----------------------------------------------------|
| `POSTGRES_USER`     | `app`        | Database owner, used by the API                     |
| `POSTGRES_PASSWORD` | **required** | Password (URL-safe characters: it goes into `DATABASE_URL`) |
| `POSTGRES_DB`       | `app`        | Database name                                       |
| `POSTGRES_PORT`     | `5432`       | Host port                                           |
| `API_PORT`          | `8080`       | Host port of `api`                                  |
| `API_DEV_PORT`      | `8081`       | Host port of `api-dev`                              |
| `API_VERSION`       | `1.0.0`      | Baked into the binary, shown by `/health`           |
| `LOG_LEVEL`         | `info`       | `debug`, `info`, `warn`, `error` (JSON logs to stdout) |

The API itself reads `DATABASE_URL`, `PORT` and `LOG_LEVEL`. Compose builds `DATABASE_URL` from the `POSTGRES_*` values.

## Default credentials

PostgreSQL: `app` / `change-me-postgres`, database `app`. The API has no auth: it's a template, so add your own middleware.

## Connecting

- **From the host**: API at http://localhost:8080. Database: `psql postgresql://app:change-me-postgres@127.0.0.1:5432/app`, or `make psql`.
- **From another container on the `backend` network**: `http://api:8080`, `postgres://app:...@postgres:5432/app`.
- **From another compose project**: join `go-api_backend` (`<project>_backend`) as an external network.

## Migrations

```bash
make migration name=add_tags     # creates migrations/000002_add_tags.{up,down}.sql
docker compose up -d --wait       # migrate runs again and applies pending ones
docker compose run --rm migrate -path=/migrations -database "postgres://app:change-me-postgres@postgres:5432/app?sslmode=disable" down 1
```

## Reset data

```bash
make reset        # asks for confirmation, then: docker compose down -v
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| `api` never starts; `migrate` exited 1 | Check `docker compose logs migrate`. A failed migration leaves the version *dirty*: fix the SQL, then `migrate ... force <version>`. |
| `password authentication failed` | The password is set when the volume is created. `make reset` after changing it, or `ALTER USER`. |
| Special characters in the password break the URL | URL-encode them (`@` → `%40`) or use letters, digits, `-` and `_`. |
| Hot reload doesn't trigger | air polls every 500 ms (`.air.toml`, `poll = true`), so it works on Docker Desktop too. Check `make logs s=api-dev` for compile errors. |
| `tmp/` appears in the folder | air's build output from `api-dev`. It's git-ignored. |
| `exec /app/api: no such file or directory` | The binary was built with CGO. Keep `CGO_ENABLED=0` for the static image. |

## Files

```
go-api/
├── cmd/api/main.go             # server + `healthcheck` subcommand, graceful shutdown
├── internal/config/            # env config
├── internal/httpapi/           # routes, handlers, middleware, unit tests
├── internal/store/             # pgx queries
├── migrations/                 # golang-migrate SQL files
├── Dockerfile, .dockerignore, .air.toml, go.mod, go.sum
├── compose.yaml, .env.example
├── Makefile                    # up, dev, down, logs, ps, reset, test, unit-test, migration, psql
└── smoke-test.sh
```
