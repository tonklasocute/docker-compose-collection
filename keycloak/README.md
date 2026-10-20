# Keycloak 26 + PostgreSQL

Keycloak (OpenID Connect / OAuth 2 / SAML identity provider) in **production mode** on PostgreSQL, built as an **optimized image**. A sample `demo` realm is imported on first start, with a SPA client (PKCE), a backend client (client credentials) and a test user. Secrets come from `.env`, not from the realm file.

## Quick start

```bash
cp .env.example .env      # change the passwords and the client secret
docker compose up -d --build --wait
make test                 # smoke test: realm import, tokens, a full PKCE login
```

Open the admin console at http://localhost:8080/admin and log in as `admin` / `change-me-keycloak`. The `demo` realm's account page is http://localhost:8080/realms/demo/account (user `demo` / `change-me-demo`).

## Services

| Service    | Image / build                       | Host port         | Notes                                   |
|------------|-------------------------------------|-------------------|-----------------------------------------|
| `keycloak` | `Dockerfile` (optimized, on `quay.io/keycloak/keycloak:26.8.1`) | `127.0.0.1:8080` | management (health, metrics) on `:9000`, internal only |
| `postgres` | `postgres:16.15-alpine3.24`         | – (internal only) | only Keycloak connects to it            |

## Image

| Stage     | What it does                                                        |
|-----------|---------------------------------------------------------------------|
| `builder` | `kc.sh build` with `KC_DB=postgres`, health and metrics enabled      |
| `final`   | the same base image + the pre-built `/opt/keycloak`, runs `start --optimized` as uid 1000 |

A stock Keycloak image re-runs this "augmentation" step on every container start. The optimized image does it once at build time, so the server process is up in about 3 seconds. The very first start takes about 10 seconds more, to create the schema and import the realm. Changing a build-time option (database vendor, features) means rebuilding the image.

**Size**: **~455 MB uncompressed / ~265 MB pull**. The build step adds only 3.25 MB on top of the official image, which is mostly the JVM (212 MB) and Keycloak itself (184 MB). The base is UBI-micro: no package manager, non-root user. Docker 29's `docker image ls` shows ~757 MB "disk usage", because its containerd store counts both the compressed and the unpacked copy.

## The demo realm

[`realms/demo-realm.json`](realms/demo-realm.json) is imported by `--import-realm` the first time Keycloak starts on an empty database. After that, realms that already exist are skipped, so changes you make in the console are kept.

| Object | Settings |
|---|---|
| client `demo-app` | public, authorization code + **PKCE (S256)** only, redirect `http://localhost:3000/*`, direct password grant **off** |
| client `demo-service` | confidential, **client credentials** only, secret = `DEMO_CLIENT_SECRET` |
| user `demo` | password = `DEMO_USER_PASSWORD`, realm role `user` |
| realm | brute-force protection on, self-registration off, roles `user` and `admin` |

`${DEMO_CLIENT_SECRET}` and `${DEMO_USER_PASSWORD}` in the JSON are replaced from the container's environment during the import, so the file is safe to commit. To add a realm, drop another `*.json` into `realms/` and run `make reset`, or import it in the console.

## Environment variables

| Variable                  | Default      | Description                                            |
|---------------------------|--------------|--------------------------------------------------------|
| `KEYCLOAK_ADMIN`          | `admin`      | Temporary master-realm admin (first start only)        |
| `KEYCLOAK_ADMIN_PASSWORD` | **required** | Its password                                           |
| `KEYCLOAK_PORT`           | `8080`       | Host port                                              |
| `KEYCLOAK_URL`            | `http://localhost:$KEYCLOAK_PORT` | Public URL: issuer in tokens, base of redirects |
| `KEYCLOAK_LOG_LEVEL`      | `INFO`       | `DEBUG`, `INFO`, `WARN`, ...                           |
| `DEMO_USER_PASSWORD`      | **required** | Password of user `demo`                                |
| `DEMO_CLIENT_SECRET`      | **required** | Secret of client `demo-service`                        |
| `POSTGRES_DB` / `POSTGRES_USER` | `keycloak` | Database and owner                                |
| `POSTGRES_PASSWORD`       | **required** | Database password                                      |

## Default credentials

| What                       | Value                                                  |
|----------------------------|--------------------------------------------------------|
| Admin console (`master`)   | `admin` / `change-me-keycloak`. Keycloak shows it as *temporary*: create a real admin, then delete it. |
| `demo` realm user          | `demo` / `change-me-demo`                              |
| `demo-service` client      | secret `change-me-demo-service-secret`                 |
| PostgreSQL                 | `keycloak` / `change-me-postgres` (not reachable from the host) |

## Connecting

**OIDC endpoints** (discovery has the rest):

```
http://localhost:8080/realms/demo/.well-known/openid-configuration
```

**A token for a backend, from the host:**

```bash
curl -s http://localhost:8080/realms/demo/protocol/openid-connect/token \
  -d grant_type=client_credentials -d client_id=demo-service -d client_secret="$DEMO_CLIENT_SECRET"
make token                # the same, prints only the access token
```

**From another container**: use `http://keycloak:8080` on the `keycloak_keycloak` network (`<project>_keycloak`). Tokens still say `iss: http://localhost:8080/realms/demo`, because the issuer is the public URL (`KEYCLOAK_URL`), not the address a request came in on. Validate tokens against that issuer, and fetch keys (JWKS) from `http://keycloak:8080/realms/demo/protocol/openid-connect/certs`. `KC_HOSTNAME_BACKCHANNEL_DYNAMIC=true` makes those internal calls work.

**Behind a reverse proxy / HTTPS**: set `KEYCLOAK_URL=https://auth.example.com`, terminate TLS in the proxy (for example [`../traefik`](../traefik)), and add `KC_PROXY_HEADERS: xforwarded` to the `keycloak` environment.

## Reset data

```bash
make reset        # asks for confirmation, then: docker compose down -v (realms, users, sessions)
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| Browser shows **"Cookie not found"** or the login page loops | You opened Keycloak on a different host than `KEYCLOAK_URL` (e.g. `127.0.0.1` vs `localhost`). Use exactly that URL. |
| `Invalid parameter: redirect_uri` | The app's callback isn't in the client's *Valid redirect URIs* (`http://localhost:3000/*` for `demo-app`). |
| `invalid_grant: Invalid user credentials` | Wrong password, or the user was locked by brute-force protection (*Users › demo › Brute force: unlock*). |
| `unauthorized_client` with grant type `password` | Intended: direct password grants are off for `demo-app`. Use the authorization-code flow. |
| Backend rejects tokens: **issuer mismatch** | Tokens carry the public `KEYCLOAK_URL` as `iss`. Configure that issuer, not `http://keycloak:8080`. |
| Edited `realms/demo-realm.json`, nothing changed | Import only creates missing realms. `make reset`, or change it in the console. |
| Startup fails or warns that an option is a *build-time* option | You changed a build-time option (`KC_DB`, `KC_FEATURES`, ...) at runtime. Put it in the `Dockerfile` and `docker compose up -d --build`. |
| Startup: `Request received during bootstrapping, returning a 503` | Normal for a few seconds after start. `/health/ready` and the healthcheck only report healthy once bootstrap and the realm import are done. |

## Files

```
keycloak/
├── Dockerfile, .dockerignore   # optimized build (kc.sh build), non-root
├── realms/demo-realm.json      # imported on first start; secrets as ${ENV} placeholders
├── compose.yaml, .env.example
├── Makefile                    # up, down, logs, ps, reset, test, token, psql
└── smoke-test.sh
```
