# Elasticsearch 8 + Kibana

A single-node Elasticsearch 8 with **security on**: authentication plus HTTPS with a generated CA. Kibana is optional. A one-shot `setup` container creates the certificates and **generates the `kibana_system` password and Kibana's encryption keys**, so the only secret you manage is `ELASTIC_PASSWORD`.

## Quick start

```bash
cp .env.example .env      # set ELASTIC_PASSWORD
docker compose up -d --wait
make test                 # smoke test: health, auth, TLS, index + search
```

Add Kibana with `make tools` (or `docker compose --profile tools up -d --wait`), then log in at http://localhost:5601 as `elastic`.

## Services

| Service         | Image                   | Host port                 | Profile   |
|-----------------|-------------------------|---------------------------|-----------|
| `setup`         | `elasticsearch:8.19.23` | – (runs once, exits 0)    | (default) |
| `elasticsearch` | `elasticsearch:8.19.23` | `127.0.0.1:9200` (HTTPS)  | (default) |
| `kibana`        | `kibana:8.19.23`        | `127.0.0.1:5601` (web)    | `tools`   |

## How setup works

[`setup/setup.sh`](setup/setup.sh) runs on every `up` and is idempotent:

1. **First run only**: creates a CA and a certificate for `elasticsearch`, `localhost` and `127.0.0.1` with `elasticsearch-certutil`, and writes random `kibana_system` and encryption-key values to `kibana.env`. Everything goes into the `certs` volume, owned by uid 1000 with mode 640.
2. Its healthcheck passes once those files exist, which starts Elasticsearch (`depends_on: service_healthy`).
3. It waits for Elasticsearch, sets the `kibana_system` password through the security API, and exits 0.
4. Kibana starts only after `setup` *completed successfully*. Its entrypoint loads `kibana.env` and then runs the stock entrypoint.

## Environment variables

| Variable           | Default          | Description                                         |
|--------------------|------------------|-----------------------------------------------------|
| `ELASTIC_PASSWORD` | **required**     | `elastic` superuser password (also the Kibana login) |
| `ES_PORT`          | `9200`           | Host port (HTTPS)                                   |
| `ES_CLUSTER_NAME`  | `docker-cluster` | Cluster name                                        |
| `ES_HEAP`          | `512m`           | JVM heap (`-Xms`/`-Xmx`)                            |
| `ES_MEMORY_LIMIT`  | `1536m`          | Container memory limit                              |
| `KIBANA_PORT`      | `5601`           | Kibana host port                                    |

## Default credentials

| What               | User            | Password                                                |
|--------------------|-----------------|---------------------------------------------------------|
| Elasticsearch / Kibana | `elastic`   | `change-me-elastic` (from `.env.example`)               |
| Kibana → ES        | `kibana_system` | generated; see `config/certs/kibana.env` in the volume  |

## Connecting

**From the host**: HTTPS with the generated CA:

```bash
make ca                                     # copies the CA to ./ca.crt (git-ignored)
curl --cacert ca.crt -u elastic:change-me-elastic https://localhost:9200
# or, for a quick look only: curl -k -u elastic:change-me-elastic https://localhost:9200
```

**From another container in this compose file**: mount the `certs` volume read-only and verify against it:

```yaml
  myapp:
    environment:
      ELASTICSEARCH_URL: https://elasticsearch:9200
      ELASTICSEARCH_CA: /certs/ca/ca.crt
    volumes:
      - certs:/certs:ro
```

**From a different compose project**: join the `elasticsearch_elastic` network (`<project>_elastic`), and use the CA from `make ca`.

## Reset data

```bash
make reset        # asks for confirmation, then: docker compose down -v
```

This also deletes the certificates and the generated Kibana credentials. New ones are made on the next start, so re-run `make ca` for host clients.

## Memory and CI

Elasticsearch takes about 1–1.5 GB and Kibana about 0.7–1 GB. Docker needs roughly 3 GB free for the whole stack. On Linux hosts with very little memory, lower `ES_HEAP` (for example `384m`).

`discovery.type=single-node` skips the production bootstrap checks, so `vm.max_map_count` doesn't need changing for this template. A multi-node cluster would need `sysctl -w vm.max_map_count=262144`.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `curl: (60) SSL certificate problem` | Use `--cacert ca.crt` (from `make ca`), or `-k` for a quick test. |
| `curl: (52) Empty reply from server` | The API is HTTPS only. Use `https://`. |
| Kibana: `Unable to retrieve version information from Elasticsearch nodes` | Check `docker compose logs setup`. The `kibana_system` password is set there. |
| `exit code 137` / container restarts | Out of memory. Raise Docker's memory or `ES_MEMORY_LIMIT`, or lower `ES_HEAP`. |
| Changed `ELASTIC_PASSWORD` but the old one still works | It's only applied to a new data volume. Use `bin/elasticsearch-reset-password -u elastic -i` or `make reset`. |
| Indices became read-only | Disk watermarks are disabled here. If you re-enabled them, free disk space and clear `index.blocks.read_only_allow_delete`. |

## Files

```
elasticsearch/
├── compose.yaml
├── .env.example
├── setup/setup.sh    # CA + certs, generated Kibana credentials, kibana_system password
├── Makefile          # up, tools, down, logs, ps, reset, test, ca
└── smoke-test.sh
```
