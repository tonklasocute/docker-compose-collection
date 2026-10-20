# MinIO-compatible S3 storage (PGSTY Silo)

A single-node MinIO server (as the maintained fork, Silo): the S3 API plus a web console. On every start, a `post_start` hook creates your buckets and an **application user that can only reach those buckets**. Your code never uses the root account.

## Quick start

```bash
cp .env.example .env      # change both passwords
docker compose up -d --wait
make test                 # smoke test: signed S3 PUT/GET/DELETE from the host, access control
```

Open the console at http://localhost:9001 and log in as `admin` / `change-me-minio`.

## Which MinIO image?

MinIO Inc. ended community distribution: the `minio/minio` images are gone from Docker Hub, and the GitHub repository is archived. This template runs **[PGSTY Silo](https://github.com/pgsty/silo)** (`pgsty/silo`) instead. Silo is a community-maintained fork of the same AGPL-3.0 server, with security releases, multi-arch images and the full web console. It keeps everything clients and data depend on: the S3 API, the `MINIO_*` variables, the `/minio/health/*` routes, `minio_*` metrics and the on-disk format. The admin client in the image is `mcli`, a renamed `mc`.

Until August 2026 the fork was published as `pgsty/minio`. That image is frozen at `RELEASE.2026-08-04T00-00-00Z`, so use `pgsty/silo` for current releases. To switch to another S3-compatible server (MinIO's commercial AIStor, SeaweedFS, Garage), change `image:`. Applications won't notice, because they only talk S3.

## Services

| Service | Image                                      | Host port                                     |
|---------|--------------------------------------------|-----------------------------------------------|
| `minio` | `pgsty/silo:RELEASE.2026-10-18T00-00-00Z` | `127.0.0.1:9000` (S3 API), `127.0.0.1:9001` (console) |

The console is built into the server binary, like RabbitMQ's management UI, so there's no `tools` profile here.

## Buckets and access

[`setup.sh`](setup.sh) runs inside the container after each start. Every step is idempotent:

1. creates each bucket in `MINIO_BUCKETS` (`app,uploads`),
2. creates the policy `app-buckets`, which allows `s3:*` on those buckets and their objects and nothing else,
3. creates the user `MINIO_APP_ACCESS_KEY` and attaches that policy.

So the app's credentials can't create buckets, read other buckets, or use the admin API. The smoke test checks that, along with denied anonymous reads. To make a bucket public (e.g. for static assets), run `make mcli a="anonymous set download local/uploads"`.

## Environment variables

| Variable               | Default         | Description                                   |
|------------------------|-----------------|-----------------------------------------------|
| `MINIO_ROOT_USER`      | `admin`         | Root user (console, `mcli admin`)             |
| `MINIO_ROOT_PASSWORD`  | **required**    | Root password, 8+ characters                  |
| `MINIO_BUCKETS`        | `app`           | Buckets to create, comma-separated (`.env.example`: `app,uploads`) |
| `MINIO_APP_ACCESS_KEY` | `app`           | S3 access key for your application            |
| `MINIO_APP_SECRET_KEY` | **required**    | S3 secret key, 8+ characters                  |
| `MINIO_PORT`           | `9000`          | S3 API host port                              |
| `MINIO_CONSOLE_PORT`   | `9001`          | Console host port                             |

## Default credentials

| What               | Value                                               |
|--------------------|-----------------------------------------------------|
| Console / root     | `admin` / `change-me-minio`                          |
| Application (S3)   | access key `app`, secret key `change-me-minio-app`  |

## Connecting

Any S3 SDK works. Use path-style addressing and any region (MinIO answers to `us-east-1`).

**From the host**

```bash
# AWS CLI
AWS_ACCESS_KEY_ID=app AWS_SECRET_ACCESS_KEY=change-me-minio-app \
  aws --endpoint-url http://localhost:9000 s3 cp ./file.txt s3://app/file.txt

# Plain curl: it signs S3 requests itself (SigV4)
curl --aws-sigv4 "aws:amz:us-east-1:s3" --user "app:change-me-minio-app" \
  -T ./file.txt http://localhost:9000/app/file.txt
```

```js
// Node.js, @aws-sdk/client-s3
new S3Client({
  endpoint: "http://localhost:9000",   // from another container: http://minio:9000
  region: "us-east-1",
  forcePathStyle: true,
  credentials: { accessKeyId: "app", secretAccessKey: process.env.S3_SECRET },
});
```

**From another container**: `http://minio:9000` on the `minio_storage` network (`<project>_storage`). Presigned URLs embed the host they were signed for, so sign them with the URL the *browser* will use (e.g. `http://localhost:9000`), not `http://minio:9000`.

## Reset data

```bash
make reset        # asks for confirmation, then: docker compose down -v
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| `SignatureDoesNotMatch` | The host in the request differs from the one that was signed. This is common with presigned URLs made for `minio:9000` and opened at `localhost:9000`. Sign for the public host. |
| `The specified bucket does not exist` / `NoSuchBucket` with virtual-host URLs | The SDK is using `bucket.localhost`. Enable path-style (`forcePathStyle` / `s3ForcePathStyle` / `addressing_style=path`). |
| `AccessDenied` for the app user | The bucket isn't in `MINIO_BUCKETS`. Add it and restart (`docker compose up -d --wait`); the hook updates the policy. |
| `docker compose up` fails with `hook exited with status 1` | Check `docker compose logs minio`. Usually a password under 8 characters. |
| `post_start` is rejected as an unknown key | Docker Compose is older than 2.30. Update it, or run `docker compose exec minio sh /usr/local/bin/setup.sh`. |
| `bind: address already in use` on 9000 | Another service is using it (often another MinIO, or PHP-FPM). Set `MINIO_PORT`. |
| Console login redirects to the wrong address | `MINIO_BROWSER_REDIRECT_URL` must match the URL you open the console at (`http://localhost:9001` by default). |

## Files

```
minio/
├── compose.yaml
├── .env.example
├── setup.sh        # post_start hook: buckets, scoped policy, app user
├── Makefile        # up, down, logs, ps, reset, test, mcli, buckets
└── smoke-test.sh
```
