# GitLab Runner (Docker executor)

A self-hosted GitLab Runner that runs each CI job in a fresh container on this machine's Docker daemon. `register.sh` connects it to gitlab.com or your own GitLab with one command, and the runner exposes Prometheus metrics.

## Quick start

```bash
cp .env.example .env      # set GITLAB_URL and RUNNER_TOKEN (glrt-...)
docker compose up -d --wait
./register.sh             # or: make register
```

To get a token: in GitLab, open your project or group, then **Settings › CI/CD › Runners › New project runner**. Choose tags there, then copy the `glrt-...` token into `.env`. The runner shows as online a few seconds after `register.sh` finishes.

```yaml
# .gitlab-ci.yml - any job now runs here (match the tags you chose)
test:
  image: node:24-alpine
  script: npm ci && npm test
```

## Services

| Service       | Image                                 | Host port                   | Defined in          |
|---------------|---------------------------------------|-----------------------------|---------------------|
| `runner`      | `gitlab/gitlab-runner:alpine-v19.5.0` | `127.0.0.1:9252` (metrics)  | `compose.yaml`      |
| `mock-gitlab` | `python:3.14.8-alpine3.24`            | – (internal)                | `compose.test.yaml` |

`mock-gitlab` is a test fixture, not part of a normal setup. It's a 130-line fake of the GitLab API ([`test/mock-gitlab.py`](test/mock-gitlab.py)) that the smoke test uses to register the runner and run a real job without a GitLab server.

## Environment variables

| Variable               | Default              | Description                                             |
|------------------------|----------------------|---------------------------------------------------------|
| `GITLAB_URL`           | `https://gitlab.com` | GitLab instance (used by `register.sh`)                 |
| `RUNNER_TOKEN`         | **required** for `register.sh` | Runner authentication token, `glrt-...`        |
| `RUNNER_NAME`          | `docker-runner`      | Name shown in GitLab's runner list                      |
| `RUNNER_DEFAULT_IMAGE` | `alpine:3.24.2`      | Image for jobs without `image:`                         |
| `RUNNER_CONCURRENT`    | `2`                  | Jobs this machine runs at the same time                 |
| `RUNNER_JOB_MEMORY`    | `2g`                 | Memory limit per job container                          |
| `RUNNER_METRICS_PORT`  | `9252`               | Host port for `/metrics`                                |

`register.sh` reads these once and writes them into `config.toml`. To change them later, edit `.env`, then run `make reset` and `./register.sh` again. You can also edit `config.toml` in place: `docker compose exec runner vi /etc/gitlab-runner/config.toml`, and the runner reloads it within seconds.

## How it works

```
GitLab  ◄──── polls for jobs (HTTPS, outbound only) ────  runner container
                                                              │ /var/run/docker.sock
                                                              ▼
                                         host Docker: job container (image: from .gitlab-ci.yml)
                                                      + gitlab-runner-helper (git clone, artifacts, cache)
```

- The runner only makes **outbound** requests to GitLab, so it works behind NAT with no open ports.
- Jobs are **sibling containers**, started through the mounted Docker socket. They are not nested inside the runner.
- `config.toml`, which holds the runner token, lives in the named volume `runner-config`. It isn't a bind mount, so the token never lands in your working tree.

## Default credentials

None. The runner authenticates to GitLab with the token stored in `config.toml`. `/metrics` has no auth and is bound to `127.0.0.1`.

## Connecting

- **From the host**: metrics at http://localhost:9252/metrics. Status: `make verify`, `make logs`.
- **From Prometheus** (e.g. [`../monitoring`](../monitoring)): scrape `runner:9252` on the `gitlab-runner_runner` network, or `host.docker.internal:9252`.
- **Building Docker images in jobs**: the default is unprivileged jobs with no Docker access. Two options:
  - *Socket binding* (fast, but jobs control the host daemon): add `"/var/run/docker.sock:/var/run/docker.sock"` to `volumes` under `[runners.docker]` in `config.toml`.
  - *Rootless builders* (safer): build with rootless BuildKit (`moby/buildkit:rootless`) or a similar daemonless builder. No config changes are needed.

## Security

Mounting `/var/run/docker.sock` gives the runner root-equivalent control of the host's Docker. That's the standard trade-off for the Docker executor on a single machine. To keep it safe:

- Use this for **your own projects**. Don't attach it as a shared runner for repositories you don't trust.
- Keep jobs unprivileged (the default, `privileged = false`).
- In production, run it on a dedicated VM. For untrusted code, use the Kubernetes or docker-autoscaler executor.

## Reset data

```bash
make unregister   # remove the runner(s) from GitLab first
make reset        # asks for confirmation, then: docker compose down -v (deletes config.toml)
```

Job caches are Docker volumes named `runner-*-cache-*` on the host. Clean them with `docker volume prune --filter label=com.gitlab.gitlab-runner.managed=true`.

## Smoke test

```bash
docker compose -f compose.yaml -f compose.test.yaml up -d --wait
make test
```

The test checks that metrics are served and the Docker socket is mounted. With `mock-gitlab` running, it then runs the real `register.sh` against the fake API, checks `config.toml`, runs `gitlab-runner verify`, and waits for a job to complete. The job runs `echo "smoke-ok $((6*7)) alpine-$(cat /etc/alpine-release)"` in an `alpine` container. The test passes only when the log GitLab receives contains `smoke-ok 42 alpine-3.`, which proves the script ran inside the job container.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `ERROR: Verifying runner... is not valid` / `403 Forbidden` | The token is wrong, expired, or the runner was deleted in GitLab. Create a new runner and register again. |
| Runner is online but jobs stay **pending** | The job's `tags:` don't match the runner's tags, or "Run untagged jobs" is off. Both are set in GitLab's runner settings. |
| `Cannot connect to the Docker daemon at unix:///var/run/docker.sock` | Docker Desktop: enable *Allow the default Docker socket to be used*. Rootless Docker: change the socket path in `compose.yaml`. |
| Self-hosted GitLab with a private CA: `x509: certificate signed by unknown authority` | Copy the CA into the volume as `/etc/gitlab-runner/certs/ca.crt` (`docker compose cp ca.crt runner:/etc/gitlab-runner/certs/ca.crt`) and restart. |
| `Job failed: execution took longer than ...` | The timeout is set per project in GitLab (Settings › CI/CD › General pipelines), and per runner in its GitLab settings. |
| Disk fills up | Old job images and cache volumes: `docker system prune` and the volume prune command above. |
| Log warns about `request_concurrency` | `register.sh` sets it from `RUNNER_CONCURRENT` (capped at 4). For runners registered by hand, set `request_concurrency` under `[[runners]]`. |

## Files

```
gitlab-runner/
├── compose.yaml
├── .env.example
├── register.sh           # gitlab-runner register (docker executor) + concurrent
├── compose.test.yaml     # test fixture: mock-gitlab (used by scripts/test-template.sh)
├── test/mock-gitlab.py   # fake GitLab API for the smoke test
├── Makefile              # up, register, verify, config, unregister, down, logs, ps, reset, test
└── smoke-test.sh
```
