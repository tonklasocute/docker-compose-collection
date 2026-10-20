#!/bin/sh
# Runs inside the minio container as a compose post_start hook: waits for the
# server, then creates the buckets in MINIO_BUCKETS and an application user
# that can only use those buckets. Safe to re-run: every step is idempotent.
set -eu

alias_ok() { mcli alias set local http://127.0.0.1:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null 2>&1; }
i=0
until alias_ok && mcli ready local >/dev/null 2>&1; do
  i=$((i + 1))
  if [ "$i" -ge 60 ]; then
    echo "setup: MinIO did not become ready within 60s" >&2
    exit 1
  fi
  sleep 1
done

resources=""
for b in $(echo "$MINIO_BUCKETS" | tr ',' ' '); do
  mcli mb --ignore-existing "local/$b"
  resources="$resources\"arn:aws:s3:::$b\",\"arn:aws:s3:::$b/*\","
done

# Policy: everything on these buckets (and their objects), nothing else
cat >/tmp/app-policy.json <<JSON
{
  "Version": "2012-10-17",
  "Statement": [
    {"Effect": "Allow", "Action": ["s3:*"], "Resource": [${resources%,}]}
  ]
}
JSON
mcli admin policy create local app-buckets /tmp/app-policy.json
mcli admin user add local "$MINIO_APP_ACCESS_KEY" "$MINIO_APP_SECRET_KEY"
if ! mcli admin user info local "$MINIO_APP_ACCESS_KEY" | grep -q app-buckets; then
  mcli admin policy attach local app-buckets --user "$MINIO_APP_ACCESS_KEY"
fi
rm -f /tmp/app-policy.json
echo "setup: buckets [$MINIO_BUCKETS] and user '$MINIO_APP_ACCESS_KEY' ready"
