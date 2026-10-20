# RabbitMQ 4 + management UI

A single RabbitMQ 4 node with the management UI and Prometheus metrics. On every start, a sample topology is declared from [`definitions.json`](definitions.json): a topic exchange, a quorum queue, and a dead-letter queue. There's no `guest` user; you get one admin user with your password.

## Quick start

```bash
cp .env.example .env      # change the password
docker compose up -d --wait
make test                 # smoke test: topology, publish/route/get, survives restart
```

Open the management UI at http://localhost:15672 and log in as `app` / `change-me-rabbitmq`.

## Services

| Service    | Image                              | Host port                                   |
|------------|------------------------------------|---------------------------------------------|
| `rabbitmq` | `rabbitmq:4.3.6-management-alpine` | `127.0.0.1:5672` (AMQP), `127.0.0.1:15672` (UI + HTTP API) |

Prometheus metrics are served on `rabbitmq:15692/metrics` inside the network. That port isn't published. The management UI is a plugin in the broker image, not a separate container, so there's no `tools` profile here.

## Topology

[`definitions.json`](definitions.json) is imported into `RABBITMQ_VHOST` by a compose `post_start` hook ([`import-definitions.sh`](import-definitions.sh)) each time the container starts. Imports are idempotent: existing objects are kept, and missing ones are created.

```
publish ──► app.events (topic) ──"#"──► app.events.audit (quorum, delivery limit 5)
                                                │ rejected 5× / expired
                                                ▼
                                    app.dlx (fanout) ──► app.dead-letter (quorum)
```

- **Quorum queues** are replicated and fsynced, and they're the recommended default since RabbitMQ 4. Classic mirrored queues are gone.
- `x-delivery-limit: 5` stops a "poison" message from being redelivered forever. After 5 attempts it goes to the dead-letter queue.

Edit `definitions.json` to declare your own exchanges and queues, or build them in the UI and save them with `make export > definitions.json`.

> **Why a hook and not `load_definitions`?** When RabbitMQ imports definitions at boot, it skips creating the default user and vhost, so the file would need a pre-hashed password. Importing over the HTTP API after start keeps the password in `.env`. `post_start` hooks need Docker Compose 2.30 or newer.

## Environment variables

| Variable             | Default      | Description                                      |
|----------------------|--------------|--------------------------------------------------|
| `RABBITMQ_USER`      | `app`        | Admin user (created on first start)              |
| `RABBITMQ_PASSWORD`  | **required** | Its password                                     |
| `RABBITMQ_VHOST`     | `app`        | Virtual host, created on first start; topology goes here |
| `RABBITMQ_AMQP_PORT` | `5672`       | AMQP host port                                   |
| `RABBITMQ_UI_PORT`   | `15672`      | Management UI / HTTP API host port               |

The user, password and vhost are only applied to an **empty** volume. To change them later, use the UI or `make admin a="..."`, or run `make reset`.

## Default credentials

| What          | Value                                                  |
|---------------|--------------------------------------------------------|
| AMQP + UI     | `app` / `change-me-rabbitmq`, vhost `app`              |
| `guest`       | does not exist                                         |

## Connecting

**From the host**

```
amqp://app:change-me-rabbitmq@localhost:5672/app
```

```bash
make queues                              # queues with message counts
make admin a="list exchanges"            # any rabbitmqadmin v2 command, already authenticated
make admin a="publish message -e app.events -k order.created -m hello"
make admin a="get messages -q app.events.audit"
```

**From another container in this compose file**

```
AMQP_URL=amqp://app:change-me-rabbitmq@rabbitmq:5672/app
```

**From a different compose project**: join the `rabbitmq_messaging` network (`<project>_messaging`) as an external network, then use the same URL.

## Reset data

```bash
make reset        # asks for confirmation, then: docker compose down -v
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| `ACCESS_REFUSED - Login was refused` | Wrong user or password, or the volume was created with an older password (`make reset`). `guest` doesn't exist here. |
| `NOT_ALLOWED - vhost / not found` | Clients default to vhost `/`. Put the vhost in the URL: `amqp://.../app`. |
| `PRECONDITION_FAILED - inequivalent arg 'x-queue-type'` | Your client declares the queue with different arguments than `definitions.json`. Declare it as quorum, or passively. |
| `docker compose up` fails with `hook exited with status 1` | `definitions.json` is invalid, or the API wasn't up within 120 s. See `docker compose logs rabbitmq`. |
| `post_start` is rejected as an unknown key | Docker Compose is older than 2.30. Update it, or run `sh import-definitions.sh` with `docker compose exec`. |
| Publishers block; log shows `memory resource limit alarm` | The broker reached its memory watermark (60% of the 1 GB limit). Consume the backlog, or raise `memory` in `compose.yaml`. |
| All data "disappeared" after re-creating the container | The node name depends on the hostname. `hostname: rabbitmq` in `compose.yaml` keeps it stable, so don't remove it. |

## Files

```
rabbitmq/
├── compose.yaml
├── .env.example
├── definitions.json         # exchanges, queues, bindings (no users/passwords)
├── import-definitions.sh    # post_start hook: imports definitions.json
├── Makefile                 # up, down, logs, ps, reset, test, admin, queues, export
└── smoke-test.sh
```
