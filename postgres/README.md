# PostgreSQL 16 + pgAdmin

PostgreSQL 16 with a ready-made application database and user, plus pgAdmin 4 as an optional web UI.

## Quick start

```bash
cp .env.example .env      # change the passwords
docker compose up -d --wait
make test                 # smoke test: SELECT 1, app-user login
```

Add pgAdmin with `make tools` (or `docker compose --profile tools up -d --wait`).

## Services

| Service    | Image                       | Host port              | Profile   |
|------------|-----------------------------|------------------------|-----------|
| `postgres` | `postgres:16.15-alpine3.24` | `127.0.0.1:5432`       | (default) |
| `pgadmin`  | `dpage/pgadmin4:9.18.0`     | `127.0.0.1:5050` (web) | `tools`   |

## Environment variables

| Variable            | Default              | Description                                           |
|---------------------|----------------------|-------------------------------------------------------|
| `POSTGRES_USER`     | `postgres`           | Superuser name                                        |
| `POSTGRES_PASSWORD` | **required**         | Superuser password                                    |
| `POSTGRES_DB`       | `postgres`           | Superuser's default database                          |
| `POSTGRES_PORT`     | `5432`               | Host port                                             |
| `APP_DB_NAME`       | `app`                | Sample database created on first start                |
| `APP_DB_USER`       | `app`                | Owner of `APP_DB_NAME` (use this from your app)       |
| `APP_DB_PASSWORD`   | **required**         | Password for `APP_DB_USER`                            |
| `PGADMIN_EMAIL`     | `admin@example.com`  | pgAdmin login                                         |
| `PGADMIN_PASSWORD`  | **required**         | pgAdmin password                                      |
| `PGADMIN_PORT`      | `5050`               | pgAdmin host port                                     |

`APP_DB_*` are only read by [`init/01-create-app-db.sh`](init/01-create-app-db.sh), which runs **once**, when the data volume is empty. Changing them later has no effect until you reset.

## Default credentials

These are the values in `.env.example`. Change them before using the stack anywhere but your own machine.

| What        | User                | Password             |
|-------------|---------------------|----------------------|
| Superuser   | `postgres`          | `change-me-postgres` |
| App user    | `app` (db `app`)    | `change-me-app`      |
| pgAdmin     | `admin@example.com` | `change-me-pgadmin`  |

In pgAdmin, the server **postgres (compose)** is already registered. Enter the superuser password the first time you open it.

## Connecting

**From the host**

```bash
psql "postgresql://app:change-me-app@127.0.0.1:5432/app"
make psql                                   # superuser shell inside the container
```

**From another container in this compose file**: use the service name as the host:

```
DATABASE_URL=postgresql://app:change-me-app@postgres:5432/app
```

**From a container in a different compose project**: join this stack's network. It is named `<project>_db`, so `postgres_db` when the folder is called `postgres` (check with `docker network ls`):

```yaml
services:
  myapp:
    networks: [postgres_db]
networks:
  postgres_db:
    external: true
```

## Reset data

```bash
make reset        # asks for confirmation, then: docker compose down -v
```

This deletes the `postgres-data` and `pgadmin-data` volumes. The init script runs again on the next start.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `required variable POSTGRES_PASSWORD is missing a value` | You have no `.env`. Run `cp .env.example .env`. |
| `port is already allocated` / `address already in use` | Another Postgres is on 5432. Set `POSTGRES_PORT=5433` in `.env`. |
| Changed `POSTGRES_PASSWORD` but the old one still works | The password is set only when the volume is created. Run `ALTER USER postgres PASSWORD '...'` or `make reset`. |
| `app` database or user doesn't exist | The volume existed before `init/` ran. Run `make reset`. |
| pgAdmin: "email address is not valid" | pgAdmin rejects reserved domains like `localhost`. Use a normal-looking address. |
| pgAdmin shows `unhealthy` for the first minute | First start runs migrations. `start_period` is 60s; check with `make logs s=pgadmin`. |

## Files

```
postgres/
├── compose.yaml
├── .env.example
├── init/01-create-app-db.sh   # creates APP_DB_* role, database and a sample table
├── pgadmin/servers.json       # pre-registers the server in pgAdmin
├── Makefile                   # up, tools, down, logs, ps, reset, test, psql
└── smoke-test.sh
```
