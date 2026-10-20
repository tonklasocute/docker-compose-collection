#!/usr/bin/env bash
# Smoke test against the running stack (`make up` first). The S3 calls are
# made from the host with curl's built-in AWS Signature v4, like any SDK would.
set -euo pipefail
cd "$(dirname "$0")"
# Git Bash on Windows rewrites /container/paths in arguments; turn that off
export MSYS_NO_PATHCONV=1

check() {
  local desc=$1 out
  shift
  if out=$("$@" 2>&1); then printf '  ✓ %s\n' "$desc"; else printf '  ✗ %s\n%s\n' "$desc" "$out"; exit 1; fi
}
env_value() { sed -n "s/^$1=//p" .env | tail -n1; }

S3="http://$(docker compose port minio 9000)"
BUCKET=$(env_value MINIO_BUCKETS | cut -d, -f1)
KEY="$(env_value MINIO_APP_ACCESS_KEY):$(env_value MINIO_APP_SECRET_KEY)"
OBJECT="smoke/test-$RANDOM.txt"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
# curl signs S3 requests itself (AWS SigV4); -w prints the HTTP status
s3() { curl -s --max-time 10 --aws-sigv4 "aws:amz:us-east-1:s3" --user "$KEY" -w '%{http_code}' "$@"; }

check "liveness and readiness endpoints answer" \
  sh -c "curl -fs '$S3/minio/health/live' && curl -fs '$S3/minio/health/ready'"
check "post_start created bucket '$BUCKET'" sh -c "docker compose exec -T minio mcli ls local | grep -q ' $BUCKET/\$'"

head -c 4096 /dev/urandom >"$TMP/upload"
check "app user uploads an object (PUT)" test "$(s3 -o /dev/null -T "$TMP/upload" "$S3/$BUCKET/$OBJECT")" = 200
check "app user downloads the same bytes (GET)" \
  sh -c "test \"\$(curl -s --aws-sigv4 aws:amz:us-east-1:s3 --user '$KEY' -o '$TMP/download' -w '%{http_code}' '$S3/$BUCKET/$OBJECT')\" = 200 &&
    cmp -s '$TMP/upload' '$TMP/download'"
check "anonymous reads are denied (403)" test "$(curl -s -o /dev/null -w '%{http_code}' "$S3/$BUCKET/$OBJECT")" = 403
check "app user cannot create other buckets (403)" test "$(s3 -o /dev/null -X PUT "$S3/not-allowed-$RANDOM")" = 403

check "objects survive a restart" sh -c "docker compose restart minio >/dev/null && docker compose up -d --wait minio >/dev/null"
check "object is still there after the restart" test "$(s3 -o /dev/null -I "$S3/$BUCKET/$OBJECT")" = 200
check "app user deletes the object (DELETE)" test "$(s3 -o /dev/null -X DELETE "$S3/$BUCKET/$OBJECT")" = 204

check "web console answers" curl -fsS --max-time 10 -o /dev/null "http://$(docker compose port minio 9001)/"
check "ports are published on 127.0.0.1 only" sh -c '
  docker compose port minio 9000 | grep -q "^127.0.0.1:" && docker compose port minio 9001 | grep -q "^127.0.0.1:"'
