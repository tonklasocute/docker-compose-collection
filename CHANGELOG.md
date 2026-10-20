# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-10-20

First release: the README-only repository rewritten as a tested collection of
Docker Compose templates.

### Added

- **Databases**: `postgres` (PostgreSQL 16 + pgAdmin), `mysql` (MySQL 8.4 LTS +
  Adminer), `mongodb` (MongoDB 7.0 single-node replica set + mongo-express),
  `redis` (Redis 7.4 with AOF + RedisInsight), `elasticsearch` (Elasticsearch 8
  with security and TLS, generated credentials, Kibana).
- **Messaging**: `kafka` (Kafka 4 in KRaft mode + Kafka UI), `rabbitmq`
  (RabbitMQ 4 + management UI, quorum and dead-letter queues declared on start).
- **Applications**: `go-api` (Go REST API, distroless non-root image, migrations,
  hot reload), `node-api` (NestJS + PostgreSQL + Redis, dev and prod targets),
  `fullstack` (Next.js + Go API + PostgreSQL behind nginx).
- **Operations**: `monitoring` (Prometheus, Grafana, node-exporter, cAdvisor with a
  provisioned dashboard and alerts), `logging` (Loki, Grafana Alloy, Grafana),
  `gitlab-runner` (Docker executor with `register.sh`), `traefik` (Traefik v3 with
  Let's Encrypt and a read-only Docker socket proxy), `keycloak` (Keycloak 26
  optimized build on PostgreSQL with a demo realm), `minio` (S3-compatible storage
  via PGSTY Silo, with bucket-scoped app credentials).
- `scripts/test-template.sh` and `scripts/test-all.sh`: end-to-end tests
  (validate, `up --wait`, smoke test, `down -v`) with optional `compose.test.yaml`
  fixtures.
- `scripts/lint.sh`: template structure, `docker compose config`, pinned images,
  shellcheck, hadolint, yamllint, actionlint and gitleaks.
- GitHub Actions: `lint.yml`, and `test.yml` (a matrix over every template, run
  weekly too, with per-template status badges). Dependabot for images, Go, npm
  and Actions.
- `new.sh` to copy a template into a project, plus `CONTRIBUTING.md`, a pull
  request template, `.editorconfig` and `.gitignore`.

[Unreleased]: https://github.com/tonklasocute/docker-compose-collection/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/tonklasocute/docker-compose-collection/releases/tag/v1.0.0
