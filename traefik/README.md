# Traefik v3 + Let's Encrypt

A reverse proxy for your other containers. Add three labels to a service and it's served at `https://<name>.<your domain>` with a Let's Encrypt certificate that renews itself. HTTP is redirected to HTTPS, security headers are added, and the dashboard sits behind a login. Traefik never touches the Docker socket directly: a read-only **socket proxy** sits in between.

## Quick start

```bash
cp .env.example .env      # DOMAIN, ACME_EMAIL, dashboard login (make htpasswd)
docker compose --profile demo up -d --wait
make test                 # smoke test: redirect, routing, headers, auth, socket-proxy
```

```bash
curl -k https://whoami.localhost         # the demo backend, through Traefik
```

The dashboard is at https://traefik.localhost/dashboard/ (`admin` / `change-me-traefik`).

`*.localhost` resolves to 127.0.0.1 in browsers and curl, so nothing needs DNS locally. Let's Encrypt can't issue certificates for `localhost`, though, so locally Traefik serves its self-signed default certificate (hence `-k`). See [Local development](#local-development).

## Services

| Service        | Image                                  | Host port                  | Profile   |
|----------------|----------------------------------------|----------------------------|-----------|
| `traefik`      | `traefik:v3.7.15`                      | `${TRAEFIK_BIND_IP}:80`, `:443` | (default) |
| `socket-proxy` | `tecnativa/docker-socket-proxy:v0.5.0` | – (internal network only)  | (default) |
| `whoami`       | `traefik/whoami:v1.12.0`               | – (via Traefik)            | `demo`    |

`whoami` has no Docker healthcheck: it's a scratch image with nothing to run one. Traefik health-checks it instead (`loadbalancer.healthcheck` labels) and stops routing to it while `/health` fails.

## Put your own service behind it

In **another** compose project:

```yaml
services:
  app:
    image: your/app:1.2.3
    labels:
      traefik.enable: "true"
      traefik.http.routers.app.rule: Host(`app.example.com`)
      traefik.http.services.app.loadbalancer.server.port: "3000"   # the port inside the container
    networks: [traefik-proxy]

networks:
  traefik-proxy:
    external: true
```

That's all. TLS, the certificate, the HTTP→HTTPS redirect and the security headers apply automatically, because they're set on the `websecure` entrypoint, not per router. Don't publish the app's port (`ports:`); Traefik reaches it over the `traefik-proxy` network.

## Production checklist

1. Point DNS for each host name (`A`/`AAAA`, or a wildcard) at the server.
2. In `.env`: `DOMAIN=example.com`, `TRAEFIK_BIND_IP=0.0.0.0`, `ACME_EMAIL=you@example.com`.
3. Test against **staging** first (`ACME_CA_SERVER=https://acme-staging-v02.api.letsencrypt.org/directory`). Production allows only 5 failed validations per host name per hour.
4. Once staging certificates appear (`make certs`), switch back to the production URL, run `make reset` (it clears the staging certificates), then `make up`.
5. Change the dashboard login: `make htpasswd u=admin p='...'`, then paste the result into `.env`.

Certificates are requested on the first request for a host name, using the HTTP-01 challenge on port 80. They're stored in the `letsencrypt` volume (`acme.json`) and renewed 30 days before expiry. Port 80 must stay reachable from the internet, even though every other request on it is redirected.

## Configuration

| Where | What |
|---|---|
| `compose.yaml` → `traefik.environment` | Static config as `TRAEFIK_*` variables (entrypoints, ACME, providers). One variable equals one CLI flag. |
| [`dynamic/middlewares.yml`](dynamic/middlewares.yml) | Dynamic config, hot-reloaded: `secure-headers` (HSTS, nosniff, frame deny, referrer policy; hides `Server`) and TLS ≥ 1.2. |
| Container labels | Routers and services: in this file for the dashboard and whoami, and in your own projects for your apps. |

Traefik takes static configuration from **one** source only: a file, CLI flags, *or* environment variables. This template uses environment variables, so `.env` (or an override file) can change a single setting, such as the ACME server, without copying the whole command line.

## Environment variables

| Variable                  | Default         | Description                                         |
|---------------------------|-----------------|-----------------------------------------------------|
| `DOMAIN`                  | `localhost`     | Base domain: `whoami.$DOMAIN`, `traefik.$DOMAIN`    |
| `TRAEFIK_BIND_IP`         | `127.0.0.1`     | Interface for 80/443 (`0.0.0.0` on a server)        |
| `PROXY_NETWORK`           | `traefik-proxy` | Shared network that routed containers join          |
| `ACME_EMAIL`              | (empty)         | Contact address for the Let's Encrypt account       |
| `ACME_CA_SERVER`          | Let's Encrypt production | ACME directory URL (staging for testing)   |
| `TRAEFIK_DASHBOARD_USERS` | **required**    | `user:bcrypt-hash`, in single quotes (`make htpasswd`) |
| `TRAEFIK_LOG_LEVEL`       | `INFO`          | `DEBUG`, `INFO`, `WARN`, `ERROR`                    |

## Default credentials

Dashboard at `https://traefik.$DOMAIN/dashboard/`: `admin` / `change-me-traefik` (the hash in `.env.example`). Replace it before exposing anything.

## Security

- **Socket proxy**: Traefik reads containers through `tecnativa/docker-socket-proxy`, which allows only `GET /containers/*` and events. Even if Traefik were compromised, it couldn't start containers or exec into them (the smoke test checks that a `POST` gets `403`). The proxy is on an `internal` network that only Traefik can reach.
- **Opt-in routing**: `exposedByDefault=false`, so a container is only routed with `traefik.enable=true`.
- **Hardened container**: `read_only`, all capabilities dropped, `no-new-privileges`. Ports 80 and 443 bind without `CAP_NET_BIND_SERVICE` because Docker 20.10+ allows unprivileged ports from 0 inside containers.
- **Nothing exposed by accident**: ports bind to `127.0.0.1` until you set `TRAEFIK_BIND_IP`.

## Local development

With `DOMAIN=localhost`, everything works over HTTPS with Traefik's self-signed certificate. Traefik logs one *"Unable to obtain ACME certificate"* error per host name, because Let's Encrypt refuses `localhost`. To get a browser-trusted local certificate:

```bash
mkdir certs && mkcert -cert-file certs/local.pem -key-file certs/local-key.pem "*.localhost"
```

Mount the folder by adding `- ./certs:/certs:ro` under `traefik.volumes`. Then add this to `dynamic/middlewares.yml` to make it the default certificate (`certs/` is git-ignored):

```yaml
tls:
  stores:
    default:
      defaultCertificate:
        certFile: /certs/local.pem
        keyFile: /certs/local-key.pem
```

## How the certificate flow is tested

The CI can't get real certificates: there's no public DNS name. [`compose.test.yaml`](compose.test.yaml) adds **[Pebble](https://github.com/letsencrypt/pebble)**, Let's Encrypt's ACME test server, and points Traefik's `ACME_CA_SERVER` at it. The smoke test then waits until `whoami.localhost` serves a certificate signed by *Pebble Intermediate CA* and finds it in `acme.json`. That covers account registration, the order, the HTTP-01 challenge flow, issuance and storage, which are the same code paths Let's Encrypt uses, all offline.

```bash
docker compose -f compose.yaml -f compose.test.yaml --profile demo up -d --wait && make test
```

## Reset data

```bash
make reset        # asks for confirmation, then: docker compose down -v (deletes acme.json)
```

Deleting `acme.json` means every certificate is requested again. Keep an eye on the Let's Encrypt rate limits (50 certificates per registered domain per week).

## Troubleshooting

| Symptom | Fix |
|---|---|
| `404 page not found` | No router matches the host name. Check the `Host(...)` rule and `traefik.enable=true`, and that the container is on `traefik-proxy`. The dashboard lists every router. |
| `Gateway Timeout` / `Bad Gateway` | Wrong `loadbalancer.server.port`, or the app isn't on the `traefik-proxy` network. |
| Browser warns *"TRAEFIK DEFAULT CERT"* on a real domain | ACME failed. Run `make logs s=traefik` and look for `acme`. Common causes: DNS not pointing here, port 80 blocked, `TRAEFIK_BIND_IP` still `127.0.0.1`, or rate limits. |
| `bind: address already in use` on 80/443 | Another web server is running. Stop it, or set `TRAEFIK_BIND_IP` to a different interface. |
| Dashboard login always fails | The hash in `.env` lost its `$` characters. Keep the value in single quotes, as `make htpasswd` prints it. |
| `network traefik-proxy declared as external, but could not be found` (in your app) | Start this stack first: it creates the network. |
| Traefik doesn't see new containers | Check `make logs s=socket-proxy`. A `403` there means a provider needs an API section that the proxy doesn't allow. |

## Files

```
traefik/
├── compose.yaml
├── compose.test.yaml        # test fixture: Pebble ACME server
├── dynamic/middlewares.yml  # security headers, TLS options (hot-reloaded)
├── .env.example
├── Makefile                 # up, demo, down, logs, ps, reset, test, htpasswd, certs
└── smoke-test.sh
```
