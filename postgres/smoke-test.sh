#!/usr/bin/env bash
# Smoke test against the running stack (`make up` or `make tools` first).
# shellcheck disable=SC2016  # $VARS in single quotes expand inside the container
set -euo pipefail
cd "$(dirname "$0")"
# Git Bash on Windows rewrites /container/paths in arguments; turn that off
export MSYS_NO_PATHCONV=1

check() {
  local desc=$1 out
  shift
  if out=$("$@" 2>&1); then printf '  ✓ %s\n' "$desc"; else printf '  ✗ %s\n%s\n' "$desc" "$out"; exit 1; fi
}
running() { docker compose ps --status running --services | grep -qx "$1"; }

check "postgres answers SELECT 1 as the superuser" \
  docker compose exec -T postgres sh -c \
  'test "$(psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT 1")" = 1'

# -h postgres goes over TCP via the service name, exactly like another
# container would, so this also checks password (scram) authentication.
check "app user logs in over the network and reads the sample table" \
  docker compose exec -T postgres sh -c \
  'PGPASSWORD="$APP_DB_PASSWORD" psql -h postgres -U "$APP_DB_USER" -d "$APP_DB_NAME" -tAc "SELECT count(*) FROM notes" | grep -qx 1'

check "port 5432 is published on 127.0.0.1" \
  sh -c 'docker compose port postgres 5432 | grep -q "^127.0.0.1:"'

if running pgadmin; then
  check "pgAdmin responds on /misc/ping" \
    curl -fsS --max-time 10 "http://$(docker compose port pgadmin 80)/misc/ping"
fi
