# Apache Kafka 4 (KRaft) + Kafka UI

A single Kafka 4 node in **KRaft mode**: the broker is its own controller, so there's no ZooKeeper. A one-shot `kafka-init` container creates your topics on startup. Kafka UI (the maintained [kafbat](https://github.com/kafbat/kafka-ui) fork) is an optional web UI behind a login.

## Quick start

```bash
cp .env.example .env
docker compose up -d --wait
make test                 # smoke test: quorum, topics, produce + consume
```

Add Kafka UI with `make tools` (or `docker compose --profile tools up -d --wait`).

## Services

| Service      | Image                    | Host port              | Profile   |
|--------------|--------------------------|------------------------|-----------|
| `kafka`      | `apache/kafka:4.3.1`     | `127.0.0.1:9092`       | (default) |
| `kafka-init` | `apache/kafka:4.3.1`     | – (runs once, exits 0) | (default) |
| `kafka-ui`   | `kafbat/kafka-ui:v1.5.0` | `127.0.0.1:8080` (web) | `tools`   |

## Listeners

| Listener     | Address                | Used by                                     |
|--------------|------------------------|---------------------------------------------|
| `EXTERNAL`   | `localhost:9092`       | Apps running on your machine                |
| `INTERNAL`   | `kafka:29092`          | Other containers on the compose network     |
| `CONTROLLER` | `kafka:9093`           | KRaft quorum (internal only, not published) |

Kafka tells clients which address to reconnect to (the *advertised* listener). That's why containers must use `kafka:29092`, not `localhost:9092`, and host apps the reverse.

## Environment variables

| Variable                   | Default                  | Description                                          |
|----------------------------|--------------------------|------------------------------------------------------|
| `KAFKA_CLUSTER_ID`         | **required** (example given) | KRaft cluster id; generate with `kafka-storage.sh random-uuid` |
| `KAFKA_PORT`               | `9092`                   | Host port (also the advertised EXTERNAL port)         |
| `KAFKA_TOPICS`             | `events,orders`          | Topics created by `kafka-init`                        |
| `KAFKA_TOPIC_PARTITIONS`   | `3`                      | Partitions for those topics                           |
| `KAFKA_AUTO_CREATE_TOPICS` | `false`                  | Auto-create topics on first use                       |
| `KAFKA_RETENTION_HOURS`    | `168`                    | Message retention                                     |
| `KAFKA_UI_USER`            | `admin`                  | Kafka UI login                                        |
| `KAFKA_UI_PASSWORD`        | **required**             | Kafka UI password                                     |
| `KAFKA_UI_PORT`            | `8080`                   | Kafka UI host port                                    |

## Default credentials

Kafka itself has no authentication: all listeners are plaintext, for local development. Kafka UI: `admin` / `change-me-kafka-ui`.

## Connecting

**From the host**

```bash
# any client: bootstrap.servers=localhost:9092
make topics
make produce t=events     # type messages, Ctrl-C to stop
make consume t=events
```

**From another container in this compose file**

```
KAFKA_BROKERS=kafka:29092
```

**From a different compose project**: join the `kafka_kafka` network (`<project>_kafka`) and use `kafka:29092`:

```yaml
services:
  myapp:
    networks: [kafka_kafka]
networks:
  kafka_kafka:
    external: true
```

## Reset data

```bash
make reset        # asks for confirmation, then: docker compose down -v
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| Client connects, then hangs / `Connection to node 1 (localhost:9092) could not be established` from a container | Containers must use `kafka:29092`. `localhost` inside a container is the container itself. |
| `UNKNOWN_TOPIC_OR_PARTITION` | Auto-creation is off. Add the topic to `KAFKA_TOPICS` and `docker compose up -d`, or set `KAFKA_AUTO_CREATE_TOPICS=true`. |
| `Invalid cluster.id` on start | `KAFKA_CLUSTER_ID` changed but the volume was formatted with the old one. Restore it or `make reset`. |
| Changed `KAFKA_PORT` and host clients fail | The advertised listener follows `KAFKA_PORT` automatically. Recreate with `docker compose up -d`. |
| `kafka-init` shows `Exited (0)` | Expected: it only creates topics, then exits. |
| Exposing Kafka to other machines | Set the EXTERNAL advertised listener to a reachable host name and add SASL/TLS first. |

## Files

```
kafka/
├── compose.yaml
├── .env.example
├── Makefile          # up, tools, down, logs, ps, reset, test, topics, produce, consume
└── smoke-test.sh
```
