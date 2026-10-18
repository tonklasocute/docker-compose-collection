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
cli() { docker compose exec -T redis redis-cli "$@"; }

check "redis answers PING" sh -c 'docker compose exec -T redis redis-cli ping | grep -qx PONG'

check "connections without the password are rejected" \
  docker compose exec -T redis sh -c 'REDISCLI_AUTH= redis-cli ping 2>&1 | grep -q NOAUTH'

check "AOF persistence is enabled" sh -c 'docker compose exec -T redis redis-cli config get appendonly | grep -qx yes'

key="smoke:$RANDOM"
check "SET / GET round-trip" sh -c "docker compose exec -T redis redis-cli set $key ok >/dev/null && docker compose exec -T redis redis-cli get $key | grep -qx ok"

# Restart and make sure the key was replayed from the append-only file
check "data survives a restart (AOF replay)" \
  sh -c "docker compose restart redis >/dev/null && docker compose up -d --wait redis >/dev/null && docker compose exec -T redis redis-cli get $key | grep -qx ok"
cli del "$key" >/dev/null

check "port 6379 is published on 127.0.0.1" \
  sh -c 'docker compose port redis 6379 | grep -q "^127.0.0.1:"'

if running redisinsight; then
  base="http://$(docker compose port redisinsight 5540)"
  check "RedisInsight /api/health is OK" curl -fsS --max-time 10 "$base/api/health"
  check "RedisInsight has the redis database pre-registered" \
    sh -c "curl -fsS --max-time 10 '$base/api/databases' | grep -q '\"host\":\"redis\"'"
fi
