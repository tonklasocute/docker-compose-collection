# Redis 7.4 + RedisInsight

Password-protected Redis 7.4 with append-only-file (AOF) persistence, so data survives restarts. RedisInsight is an optional web UI with the database already registered.

## Quick start

```bash
cp .env.example .env      # change the password
docker compose up -d --wait
make test                 # smoke test: PING, auth, AOF, survives restart
```

Add RedisInsight with `make tools` (or `docker compose --profile tools up -d --wait`).

## Services

| Service        | Image                      | Host port              | Profile   |
|----------------|----------------------------|------------------------|-----------|
| `redis`        | `redis:7.4.11-alpine3.21`  | `127.0.0.1:6379`       | (default) |
| `redisinsight` | `redis/redisinsight:3.4.2` | `127.0.0.1:5540` (web) | `tools`   |

## Environment variables

| Variable            | Default      | Description                 |
|---------------------|--------------|-----------------------------|
| `REDIS_PASSWORD`    | **required** | Password (`AUTH <password>`) |
| `REDIS_PORT`        | `6379`       | Host port                   |
| `REDISINSIGHT_PORT` | `5540`       | RedisInsight host port      |

## Persistence and memory

Settings live in [`redis.conf`](redis.conf):

- **AOF** (`appendonly yes`, `appendfsync everysec`): every write is logged and fsynced once a second, so a crash loses at most about one second of writes. Periodic RDB snapshots (`/data/dump.rdb`) are kept too, for backups.
- **`maxmemory 256mb` + `noeviction`**: once full, writes fail rather than keys being dropped silently. For a pure cache, switch to `allkeys-lru`.

## Default credentials

| What         | Value                                                       |
|--------------|-------------------------------------------------------------|
| Redis        | password `change-me-redis` (from `.env.example`)            |
| RedisInsight | no login; open http://localhost:5540, database **redis (compose)** |

## Connecting

**From the host**

```bash
redis-cli -h 127.0.0.1 -p 6379 -a change-me-redis ping
make cli                                    # redis-cli inside the container, already authenticated
```

**From another container in this compose file**

```
REDIS_URL=redis://:change-me-redis@redis:6379/0
```

**From a different compose project**: join the `redis_cache` network (`<project>_cache`, see `docker network ls`):

```yaml
services:
  myapp:
    networks: [redis_cache]
networks:
  redis_cache:
    external: true
```

## Reset data

```bash
make reset        # asks for confirmation, then: docker compose down -v
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| `NOAUTH Authentication required` | Pass the password: `redis-cli -a ...`, or `redis://:password@host:6379`. |
| `OOM command not allowed when used memory > 'maxmemory'` | Raise `maxmemory` in `redis.conf` (and the 512m limit in `compose.yaml`), or use an eviction policy. |
| Log warns `Memory overcommit must be enabled` | Harmless for dev. On a Linux server, run `sysctl vm.overcommit_memory=1`. |
| `Bad file format reading the append only file` | The AOF was truncated by a hard crash. Run `docker compose run --rm redis redis-check-aof --fix /data/appendonlydir/*.manifest`. |
| The password shows in `docker inspect` | It's passed as `--requirepass`. For shared hosts, use an ACL file instead. |

## Files

```
redis/
├── compose.yaml
├── .env.example
├── redis.conf        # AOF, RDB snapshots, memory policy
├── Makefile          # up, tools, down, logs, ps, reset, test, cli
└── smoke-test.sh
```
