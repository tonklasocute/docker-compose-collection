# MongoDB 7.0 (replica set) + mongo-express

MongoDB 7.0 running as a **single-node replica set**, so multi-document transactions and change streams work just as they do in production. Auth is on, and a least-privilege app user is created on first start. mongo-express is an optional web UI.

## Quick start

```bash
cp .env.example .env      # change the passwords
docker compose up -d --wait
make test                 # smoke test: PRIMARY, app-user login, a transaction
```

Add mongo-express with `make tools` (or `docker compose --profile tools up -d --wait`).

## Services

| Service         | Image                                | Host port               | Profile   |
|-----------------|--------------------------------------|-------------------------|-----------|
| `mongodb`       | `mongo:7.0.45`                       | `127.0.0.1:27017`       | (default) |
| `mongo-express` | `mongo-express:1.0.2-20-alpine3.19`  | `127.0.0.1:8081` (web)  | `tools`   |

## Environment variables

| Variable                 | Default      | Description                                          |
|--------------------------|--------------|------------------------------------------------------|
| `MONGO_ROOT_USER`        | `root`       | Root user (in `admin`)                               |
| `MONGO_ROOT_PASSWORD`    | **required** | Root password                                        |
| `MONGO_REPLICA_SET`      | `rs0`        | Replica set name                                     |
| `MONGO_PORT`             | `27017`      | Host port                                            |
| `APP_DB_NAME`            | `app`        | Sample database                                      |
| `APP_DB_USER`            | `app`        | `readWrite` on `APP_DB_NAME` only                    |
| `APP_DB_PASSWORD`        | **required** | Password for `APP_DB_USER`                           |
| `MONGO_EXPRESS_USER`     | `admin`      | mongo-express login                                  |
| `MONGO_EXPRESS_PASSWORD` | **required** | mongo-express password                               |
| `MONGO_EXPRESS_PORT`     | `8081`       | mongo-express host port                              |

Passwords are embedded in connection URLs. Use letters, digits, `-` and `_`, or URL-encode them.

## How the replica set is set up

1. [`keyfile-entrypoint.sh`](keyfile-entrypoint.sh) creates a random keyfile in the `mongodb-config` volume (mode 400, owned by `mongodb`), then runs the official entrypoint. Members of a replica set with auth enabled authenticate to each other with this file. A bind-mounted file can't be used because Docker Desktop shows it as 0777, and mongod refuses that.
2. On first start, the official entrypoint creates the root user and runs [`init/01-create-app-user.js`](init/01-create-app-user.js).
3. The **healthcheck** runs `rs.initiate()` if the set isn't initiated yet. It reports healthy only once the node is a writable primary, so `depends_on: service_healthy` really does mean "ready for writes".

The member is registered as `mongodb:27017`, its name on the compose network.

## Default credentials

| What          | User              | Password            |
|---------------|-------------------|---------------------|
| Root          | `root`            | `change-me-root`    |
| App user      | `app` (db `app`)  | `change-me-app`     |
| mongo-express | `admin`           | `change-me-express` |

## Connecting

**From the host**: add `directConnection=true`. Without it, the driver discovers the member `mongodb:27017`, a hostname that only resolves inside Docker:

```bash
mongosh "mongodb://app:change-me-app@127.0.0.1:27017/app?directConnection=true"
make shell                                  # mongosh as root inside the container
```

**From another container in this compose file**

```
MONGODB_URI=mongodb://app:change-me-app@mongodb:27017/app?replicaSet=rs0
```

**From a different compose project**: join the `mongodb_db` network (`<project>_db`). The URL above then works unchanged:

```yaml
services:
  myapp:
    networks: [mongodb_db]
networks:
  mongodb_db:
    external: true
```

## Reset data

```bash
make reset        # asks for confirmation, then: docker compose down -v
```

This removes the data, the keyfile and the replica set config. Everything is recreated on the next start.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `getaddrinfo ENOTFOUND mongodb` / server selection timeout from the host | Add `?directConnection=true` (see above). |
| `Transaction numbers are only allowed on a replica set member` | You are connected to a different, standalone mongod. Check the port. |
| `permissions on /data/configdb/keyfile are too open` | You replaced the entrypoint. Keep `keyfile-entrypoint.sh`, or `make reset`. |
| `Authentication failed` after changing `.env` | Users are created on first start only. Run `make reset` or `db.changeUserPassword()`. |
| mongo-express says `Could not connect` | It needs the root URL with `authSource=admin&replicaSet=rs0`. Check `MONGO_ROOT_PASSWORD` has no URL-special characters. |

## Files

```
mongodb/
├── compose.yaml
├── .env.example
├── keyfile-entrypoint.sh       # creates the replica-set keyfile, then runs the official entrypoint
├── init/01-create-app-user.js  # app user + sample collection
├── Makefile                    # up, tools, down, logs, ps, reset, test, shell
└── smoke-test.sh
```
