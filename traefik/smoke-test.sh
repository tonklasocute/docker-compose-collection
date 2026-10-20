#!/usr/bin/env bash
# Smoke test against the running stack (`make demo` first).
# With Pebble running (compose.test.yaml), also checks that a certificate was
# issued over ACME.
# test-profiles: demo
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
env_value() { sed -n "s/^$1=//p" "${2:-.env}" | tail -n1 | sed "s/^'\(.*\)'$/\1/"; }

DOMAIN=$(env_value DOMAIN)
DOMAIN=${DOMAIN:-localhost}
IP=$(docker compose port traefik 443 | cut -d: -f1)
# curl to <name>.$DOMAIN on the published ports, without touching DNS
web() {
  local host=$1
  shift
  curl -sk --max-time 10 --resolve "$host:80:$IP" --resolve "$host:443:$IP" "$@"
}
status() { web "$1" -o /dev/null -w '%{http_code}' "${@:2}"; }

socket_denies_writes() {
  local out
  out=$(docker compose exec -T socket-proxy sh -c \
    'wget -qO- --post-data "{}" http://127.0.0.1:2375/containers/create 2>&1; true')
  grep -q 403 <<<"$out" || { echo "$out"; return 1; }
}
redirects_to_https() {
  local out
  out=$(web "whoami.$DOMAIN" -o /dev/null -w '%{http_code} %{redirect_url}' "http://whoami.$DOMAIN/")
  [[ "$out" =~ ^30[18]\ https://whoami\.$DOMAIN/ ]] || { echo "got: $out"; return 1; }
}
security_headers() {
  local h
  h=$(web "whoami.$DOMAIN" -D - -o /dev/null "https://whoami.$DOMAIN/")
  if ! grep -qi '^strict-transport-security: max-age=31536000' <<<"$h" ||
    ! grep -qi '^x-content-type-options: nosniff' <<<"$h"; then
    echo "$h"
    return 1
  fi
}
routed_over_https() {
  web "whoami.$DOMAIN" "https://whoami.$DOMAIN/" | grep -q 'X-Forwarded-Proto: https'
}
dashboard_lists_routers() {
  web "traefik.$DOMAIN" -u admin:change-me-traefik "https://traefik.$DOMAIN/api/http/routers" | grep -q dashboard@docker
}
pebble_issued() {
  local out=""
  for _ in $(seq 1 30); do
    out=$(openssl s_client -connect "$IP:443" -servername "whoami.$DOMAIN" </dev/null 2>/dev/null |
      openssl x509 -noout -issuer 2>/dev/null) || true
    grep -q 'Pebble Intermediate CA' <<<"$out" && return 0
    sleep 2
  done
  echo "certificate issuer: ${out:-none}"
  docker compose logs --tail=20 traefik
  return 1
}

check "traefik answers /ping" docker compose exec -T traefik traefik healthcheck --ping
check "socket-proxy allows reading containers" \
  sh -c 'docker compose exec -T socket-proxy wget -qO- http://127.0.0.1:2375/containers/json | grep -q "\"Id\""'
check "socket-proxy denies writes (POST /containers/create: 403)" socket_denies_writes

if running whoami; then
  check "HTTP redirects to HTTPS" redirects_to_https
  check "whoami.$DOMAIN is routed over HTTPS" routed_over_https
  check "security headers are set (HSTS, nosniff)" security_headers
fi
check "unknown hosts get 404" test "$(status "nope.$DOMAIN" "https://nope.$DOMAIN/")" = 404

check "dashboard requires a login" test "$(status "traefik.$DOMAIN" "https://traefik.$DOMAIN/dashboard/")" = 401
# Only the example hash has a known password
if [[ "$(env_value TRAEFIK_DASHBOARD_USERS)" == "$(env_value TRAEFIK_DASHBOARD_USERS .env.example)" ]]; then
  check "dashboard API lists the routers (example login)" dashboard_lists_routers
fi

if running pebble && running whoami; then
  check "ACME: whoami.$DOMAIN serves a certificate issued by Pebble" pebble_issued
  check "ACME: the certificate is stored in acme.json" \
    sh -c "docker compose exec -T traefik cat /letsencrypt/acme.json | grep -q '\"main\": \"whoami.$DOMAIN\"'"
fi
