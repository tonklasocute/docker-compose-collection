#!/usr/bin/env bash
# Smoke test against the running stack (`make up` first).
#
# End to end: start a throwaway container that prints a unique line, then
# wait until that exact line can be queried from Loki with its labels.
set -euo pipefail
cd "$(dirname "$0")"
# Git Bash on Windows rewrites /container/paths in arguments; turn that off
export MSYS_NO_PATHCONV=1

check() {
  local desc=$1 out
  shift
  if out=$("$@" 2>&1); then printf '  ✓ %s\n' "$desc"; else printf '  ✗ %s\n%s\n' "$desc" "$out"; exit 1; fi
}
env_value() { grep "^$1=" .env | cut -d= -f2-; }

LOKI="http://$(docker compose port loki 3100)"
ALLOY="http://$(docker compose port alloy 12345)"
GRAFANA="http://$(docker compose port grafana 3000)"
AUTH="$(env_value GRAFANA_ADMIN_USER):$(env_value GRAFANA_ADMIN_PASSWORD)"

PROBE="dcc-log-probe-$RANDOM"
MARKER="smoke-marker-$RANDOM-$(date +%s)"
trap 'docker rm -f "$PROBE" >/dev/null 2>&1 || true' EXIT

logql() {
  curl -fsS --max-time 10 -G "$LOKI/loki/api/v1/query_range" \
    --data-urlencode "query=$1" --data-urlencode "since=10m" --data-urlencode "limit=10"
}

probe_line_in_loki() {
  local body
  for _ in $(seq 1 30); do
    body=$(logql "{container=\"$PROBE\"} |= \"$MARKER\"" || true)
    if grep -q "$MARKER" <<<"$body"; then return 0; fi
    sleep 2
  done
  echo "last response: $body"
  return 1
}

check "Loki is ready" curl -fsS --max-time 10 "$LOKI/ready"
check "Alloy is ready" curl -fsS --max-time 10 "$ALLOY/-/ready"

docker run -d --name "$PROBE" --label logging-probe=true busybox:1.38.0 \
  sh -c "echo '$MARKER'; sleep 120" >/dev/null
check "a new container's log line reaches Loki (Docker -> Alloy -> Loki)" probe_line_in_loki

check "compose services are labelled (compose_service=\"loki\" has logs)" \
  sh -c "curl -fsS -G '$LOKI/loki/api/v1/label/compose_service/values' --data-urlencode since=10m | grep -q '\"loki\"'"

check "Grafana /api/health reports database ok" \
  sh -c "curl -fsS --max-time 10 '$GRAFANA/api/health' | grep -q '\"database\": *\"ok\"'"
check "Loki datasource is provisioned and healthy" \
  sh -c "curl -fsS --max-time 15 -u '$AUTH' '$GRAFANA/api/datasources/uid/loki/health' | grep -q '\"status\":\"OK\"'"
check "'Container Logs' dashboard is provisioned" \
  sh -c "curl -fsS --max-time 10 -u '$AUTH' '$GRAFANA/api/dashboards/uid/container-logs' | grep -q '\"title\":\"Container Logs\"'"
