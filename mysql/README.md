# MySQL 8.4 LTS + Adminer

MySQL 8.4 (the current long-term-support line) with an application database, a least-privilege app user and a sample table. Adminer is an optional web UI.

## Quick start

```bash
cp .env.example .env      # change the passwords
docker compose up -d --wait
make test                 # smoke test: SELECT 1, app-user login, privileges
```

Add Adminer with `make tools` (or `docker compose --profile tools up -d --wait`).

## Services

| Service   | Image           | Host port              | Profile   |
|-----------|-----------------|------------------------|-----------|
| `mysql`   | `mysql:8.4.11`  | `127.0.0.1:3306`       | (default) |
| `adminer` | `adminer:5.5.1` | `127.0.0.1:8080` (web) | `tools`   |

## Environment variables

| Variable                 | Default      | Description                                      |
|--------------------------|--------------|--------------------------------------------------|
| `MYSQL_ROOT_PASSWORD`    | **required** | `root` password                                  |
| `MYSQL_DATABASE`         | `app`        | Database created on first start                  |
| `MYSQL_USER`             | `app`        | User with full rights on `MYSQL_DATABASE` only   |
| `MYSQL_PASSWORD`         | **required** | Password for `MYSQL_USER`                        |
| `MYSQL_PORT`             | `3306`       | Host port                                        |
| `MYSQL_BUFFER_POOL_SIZE` | `256M`       | `innodb_buffer_pool_size`                        |
| `TZ`                     | `UTC`        | Server time zone                                 |
| `ADMINER_PORT`           | `8080`       | Adminer host port                                |

The database, user and [`init/01-sample-schema.sql`](init/01-sample-schema.sql) are applied **once**, when the volume is empty.

## Default credentials

These are the values in `.env.example`. Change them before using the stack anywhere but your own machine.

| What     | User              | Password         |
|----------|-------------------|------------------|
| Root     | `root`            | `change-me-root` |
| App user | `app` (db `app`)  | `change-me-app`  |

Adminer: open http://localhost:8080. The server is pre-filled as `mysql`; log in with either account.

## Connecting

**From the host**

```bash
mysql -h 127.0.0.1 -P 3306 -u app -p app
make mysql                                  # root shell inside the container
```

**From another container in this compose file**

```
DATABASE_URL=mysql://app:change-me-app@mysql:3306/app
```

**From a different compose project**: join the `mysql_db` network (`<project>_db`, see `docker network ls`):

```yaml
services:
  myapp:
    networks: [mysql_db]
networks:
  mysql_db:
    external: true
```

## Reset data

```bash
make reset        # asks for confirmation, then: docker compose down -v
```

## Tuning

Server options are passed as `command:` flags in `compose.yaml`, not a mounted `my.cnf`. On Docker Desktop, bind-mounted files show up as world-writable, and MySQL silently ignores world-writable config files. Add more flags to that list, e.g. `--slow-query-log=ON`.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `required variable MYSQL_ROOT_PASSWORD is missing a value` | You have no `.env`. Run `cp .env.example .env`. |
| `port is already allocated` | Another MySQL is on 3306. Set `MYSQL_PORT=3307` in `.env`. |
| Stays `starting` for ~30s on first run | Normal: MySQL initialises the data dir and runs `init/` before it accepts TCP connections. |
| `Access denied for user 'app'` after changing `.env` | Users are created only on first start. Run `make reset` or `ALTER USER`. |
| `Public Key Retrieval is not allowed` (JDBC) | Add `allowPublicKeyRetrieval=true` or use SSL. 8.4 defaults to `caching_sha2_password`. |

## Files

```
mysql/
├── compose.yaml
├── .env.example
├── init/01-sample-schema.sql   # sample table in MYSQL_DATABASE
├── Makefile                    # up, tools, down, logs, ps, reset, test, mysql
└── smoke-test.sh
```
