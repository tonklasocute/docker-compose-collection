# docker-compose-collection

**Tested Docker Compose stacks you can copy into a project and start with one command:** databases, message brokers, observability, auth, and full app templates.

[![lint](https://github.com/tonklasocute/docker-compose-collection/actions/workflows/lint.yml/badge.svg)](https://github.com/tonklasocute/docker-compose-collection/actions/workflows/lint.yml)
[![test](https://github.com/tonklasocute/docker-compose-collection/actions/workflows/test.yml/badge.svg)](https://github.com/tonklasocute/docker-compose-collection/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/github/license/tonklasocute/docker-compose-collection)](LICENSE)
[![Last commit](https://img.shields.io/github/last-commit/tonklasocute/docker-compose-collection)](https://github.com/tonklasocute/docker-compose-collection/commits/main)

Every template here is started, health-checked and exercised in CI on each change, and again every week. The test is a real one: Kafka produces and consumes a message, Keycloak completes a PKCE login, GitLab Runner runs a job through the Docker executor, and Traefik obtains a certificate over ACME. Versions are pinned, secrets live in `.env`, and nothing listens beyond `127.0.0.1` unless you ask it to.

## Run any stack in 30 seconds

```bash
git clone https://github.com/tonklasocute/docker-compose-collection.git
cd docker-compose-collection/postgres
cp .env.example .env && docker compose up -d --wait
```

`--wait` returns once every service reports healthy. Then:

```bash
make test     # the template's smoke test
make          # every shortcut: up, down, logs, ps, reset, test, plus template-specific ones
```

To start your own project from a template, copy it out with `./new.sh`:

```bash
./new.sh postgres ~/code/my-app/infra/db     # copies the folder and creates .env
```

## Templates

| Template | What's inside | Host ports (127.0.0.1) | CI |
|---|---|---|---|
| [`postgres`](postgres) | PostgreSQL 16, init script creating an app DB/user; pgAdmin with the server pre-registered | 5432, pgAdmin 5050 | ![postgres](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/tonklasocute/docker-compose-collection/badges/postgres.json) |
| [`mysql`](mysql) | MySQL 8.4 LTS, app DB/user; Adminer | 3306, Adminer 8080 | ![mysql](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/tonklasocute/docker-compose-collection/badges/mysql.json) |
| [`mongodb`](mongodb) | MongoDB 7.0 as a single-node **replica set** (transactions, change streams); mongo-express | 27017, UI 8081 | ![mongodb](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/tonklasocute/docker-compose-collection/badges/mongodb.json) |
| [`redis`](redis) | Redis 7.4 with password and **AOF** persistence; RedisInsight | 6379, UI 5540 | ![redis](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/tonklasocute/docker-compose-collection/badges/redis.json) |
| [`elasticsearch`](elasticsearch) | Elasticsearch 8 with **security + TLS on**, generated certificates and Kibana password; Kibana | 9200, Kibana 5601 | ![elasticsearch](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/tonklasocute/docker-compose-collection/badges/elasticsearch.json) |
| [`kafka`](kafka) | Kafka 4 in **KRaft mode** (no ZooKeeper), topics created on start; Kafka UI | 9092, UI 8080 | ![kafka](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/tonklasocute/docker-compose-collection/badges/kafka.json) |
| [`go-api`](go-api) | Go REST API: **distroless, non-root, ~13 MB** image, golang-migrate, hot reload with air (`dev` profile); PostgreSQL | API 8080, dev 8081, 5432 | ![go-api](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/tonklasocute/docker-compose-collection/badges/go-api.json) |
| [`node-api`](node-api) | NestJS API with `dev` (watch) and `prod` targets; PostgreSQL + Redis | API 3000, dev 3001, 5432, 6379 | ![node-api](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/tonklasocute/docker-compose-collection/badges/node-api.json) |
| [`fullstack`](fullstack) | Next.js (standalone) + Go API + PostgreSQL behind an **nginx** reverse proxy | 8080 | ![fullstack](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/tonklasocute/docker-compose-collection/badges/fullstack.json) |
| [`monitoring`](monitoring) | Prometheus + Grafana + node-exporter + cAdvisor, provisioned datasource, dashboard and alert rules | Grafana 3000, Prometheus 9090 | ![monitoring](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/tonklasocute/docker-compose-collection/badges/monitoring.json) |
| [`logging`](logging) | Loki + **Grafana Alloy** (Promtail's successor) + Grafana, collecting every container's logs | Grafana 3000, Loki 3100 | ![logging](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/tonklasocute/docker-compose-collection/badges/logging.json) |
| [`gitlab-runner`](gitlab-runner) | GitLab Runner with the Docker executor, `register.sh`, Prometheus metrics | metrics 9252 | ![gitlab-runner](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/tonklasocute/docker-compose-collection/badges/gitlab-runner.json) |
| [`minio`](minio) | S3-compatible storage (MinIO via the maintained **Silo** fork), buckets + bucket-scoped app user created on start | S3 9000, console 9001 | ![minio](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/tonklasocute/docker-compose-collection/badges/minio.json) |
| [`rabbitmq`](rabbitmq) | RabbitMQ 4 + management UI, quorum queue and dead-letter topology declared on start | 5672, UI 15672 | ![rabbitmq](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/tonklasocute/docker-compose-collection/badges/rabbitmq.json) |
| [`traefik`](traefik) | Traefik v3 HTTPS reverse proxy with automatic **Let's Encrypt**, read-only Docker socket proxy | 80, 443 | ![traefik](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/tonklasocute/docker-compose-collection/badges/traefik.json) |
| [`keycloak`](keycloak) | Keycloak 26, **optimized build**, production mode on PostgreSQL, demo realm (PKCE + client-credentials clients) | 8080 | ![keycloak](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/tonklasocute/docker-compose-collection/badges/keycloak.json) |

Admin UIs (pgAdmin, Adminer, mongo-express, RedisInsight, Kibana, Kafka UI) sit in the `tools` profile: `make tools`, or `docker compose --profile tools up -d --wait`. Several templates use the same default port (3000, 8080, 5432), so change `*_PORT` in `.env` to run them side by side.

Each folder's README covers the services and ports, every environment variable, default credentials, connecting from the host and from other containers, resetting data, and troubleshooting.

![Grafana dashboard from the monitoring template](monitoring/docs/dashboard.png)

## App image sizes

The app templates build their own images: multi-stage, non-root, with a `.dockerignore`. These are the final sizes. *Pull* is the compressed download.

| Template | Image | Base | Uncompressed / pull |
|---|---|---|---|
| `go-api` | `api` (`final` target) | `distroless/static-debian13:nonroot` | **~13 MB / 5.2 MB** |
| `fullstack` | `api` | `distroless/static-debian13:nonroot` | **~13 MB / 5.2 MB** |
| `fullstack` | `web` (Next.js standalone) | `node:24-alpine`, npm removed | **~188 MB / 75 MB** |
| `node-api` | `api` (`prod` target) | `node:24-alpine`, prod deps only | **~207 MB / 69 MB** |
| `keycloak` | `keycloak` (optimized) | `quay.io/keycloak/keycloak` (UBI-micro) | **~455 MB / 265 MB** (the build step adds 3.25 MB) |
| `logging` | `loki` + static busybox for the healthcheck | `grafana/loki` | upstream + ~1 MB |

Docker 29's `docker image ls` shows larger "disk usage" numbers, because its containerd image store counts both the compressed and the unpacked copy.

## Conventions

Every template follows the same rules. CI enforces the ones a script can check.

**Configuration**
- `compose.yaml`, the current file name, with no obsolete `version:` key.
- **Pinned image versions**, never `latest`. Tags are literal strings, so Dependabot can bump them, and every bump goes through the test suite. `scripts/lint.sh` resolves each image and fails on untagged or `latest` ones.
- `.env.example` documents every variable. Secrets are required with `${VAR:?message}`, so a missing password stops `docker compose up` with a clear error instead of starting with a blank one. Everything else has a default. `.env` is git-ignored, and CI runs gitleaks over the full history.

**Startup order and health**
- Every long-running service has a **healthcheck** that tests real readiness (`pg_isready`, `redis-cli ping`, Keycloak's `/health/ready`, a Kafka API request), not just "the process is running". Images without a shell get a check that needs none: the Go binary has a `healthcheck` subcommand, and Keycloak's speaks HTTP over bash's `/dev/tcp`.
- `depends_on` uses `condition: service_healthy`. One-shot steps (migrations, certificate setup) use `service_completed_successfully`, or a `post_start` hook when nothing depends on them, so `docker compose up --wait` means the stack is actually usable.
- The rare service that can't have a healthcheck (scratch images like `traefik/whoami`) says so in a comment, along with what checks it instead.

**Data, networks, resources**
- Named volumes for data, so `docker compose down -v` (`make reset`, which asks first) is the one way to wipe it.
- A named network per stack, and `restart: unless-stopped`.
- Memory limits on every service whose usage can grow (JVMs, databases, caches).

**Security defaults**
- Ports bind to **`127.0.0.1`**. Each one has a comment explaining how to expose it, and most smoke tests check the binding. Internal-only databases (keycloak, fullstack) aren't published at all.
- App containers run as **non-root**, with `read_only: true`, `cap_drop: [ALL]` and `no-new-privileges` where the app allows it. The smoke tests check this too.
- No default passwords that work out of the box in production: every example password is `change-me-...`.
- The Docker socket is only mounted where it's the point of the template (GitLab Runner, Alloy, cAdvisor), and Traefik reads it through a read-only proxy.

**Profiles**
- `tools`: optional admin UIs. `dev`: hot-reload variants of app services. `demo`: example backends (Traefik's whoami). A plain `docker compose up` starts only what an app needs.

**Interface**
- Every template has the same `Makefile` targets (`up`, `down`, `logs`, `ps`, `reset`, `test`) and a `smoke-test.sh` that runs against the live stack.

## Testing

`scripts/test-template.sh <name>` tests a template the way a user would run it:

1. copies the template to `.tmp/` and creates `.env` from `.env.example`;
2. `docker compose config` (static validation);
3. `docker compose up -d --build --wait` (every healthcheck must turn green);
4. runs the template's `smoke-test.sh`;
5. `docker compose down -v`, always, even on failure (with logs printed for diagnosis).

```bash
scripts/test-template.sh kafka          # one template
scripts/test-template.sh kafka --keep   # leave it running to debug
scripts/test-all.sh                     # all of them, then a pass/fail table
scripts/lint.sh                         # structure, compose config, shellcheck, hadolint, yamllint, actionlint, gitleaks
```

Test-only fixtures live in an optional `compose.test.yaml` overlay that the test script layers on top, so `compose.yaml` stays production-shaped. `gitlab-runner` uses one for a mock GitLab API, and `traefik` uses one for [Pebble](https://github.com/letsencrypt/pebble), Let's Encrypt's ACME test server.

In CI, [`lint.yml`](.github/workflows/lint.yml) runs `scripts/lint.sh` on every push and pull request. [`test.yml`](.github/workflows/test.yml) runs every template as a matrix on `ubuntu-latest` (4 vCPU / 16 GB is enough for all of them, Elasticsearch + Kibana included), weekly as well, and publishes the per-template badges above.

## Requirements

- Docker Engine 24+ or Docker Desktop, with **Docker Compose 2.30+** (`post_start` hooks).
- `make` and `bash` for the shortcuts and scripts (on Windows: Git Bash or WSL). The plain `docker compose` commands in each README work without them.
- CI runs on Linux (amd64). The templates are developed and tested on macOS (Apple silicon, arm64). Every image used is multi-arch.

## Repository layout

```
docker-compose-collection/
├── <template>/             # one self-contained folder per stack
│   ├── compose.yaml
│   ├── .env.example
│   ├── README.md
│   ├── Makefile
│   ├── smoke-test.sh
│   └── compose.test.yaml   # optional: test-only fixtures
├── scripts/
│   ├── test-template.sh    # end-to-end test of one template
│   ├── test-all.sh         # all templates + summary table
│   └── lint.sh             # static checks (what lint.yml runs)
├── new.sh                  # copy a template into your project
└── .github/                # workflows, Dependabot, PR template
```

## Contributing

New templates and fixes are welcome. [CONTRIBUTING.md](CONTRIBUTING.md) has the template checklist and how to test locally. Changes are listed in [CHANGELOG.md](CHANGELOG.md).

## License

[MIT](LICENSE) © Khomkrit Daengnuan
