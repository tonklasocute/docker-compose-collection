#!/usr/bin/env bash
# Smoke test against the running stack (`make up` first).
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

PROM="http://$(docker compose port prometheus 9090)"
GRAFANA="http://$(docker compose port grafana 3000)"
AUTH="$(env_value GRAFANA_ADMIN_USER):$(env_value GRAFANA_ADMIN_PASSWORD)"

promql() { curl -fsS --max-time 10 -G --data-urlencode "query=$1" "$PROM/api/v1/query"; }

# Targets are scraped every 15s, so give them up to a minute to report in
all_targets_up() {
  local body
  for _ in $(seq 1 20); do
    body=$(promql 'count(up == 1) == count(up)' || true)
    if grep -q '"result":\[{' <<<"$body" && [[ "$(promql 'count(up)')" == *'"4"]'* ]]; then return 0; fi
    sleep 3
  done
  curl -fsS "$PROM/api/v1/targets?state=active" | grep -o '"scrapeUrl":"[^"]*","globalUrl":"[^"]*","lastError":"[^"]*","lastScrape":"[^"]*","lastScrapeDuration":[^,]*,"health":"[^"]*"'
  return 1
}

check "Prometheus is ready" curl -fsS --max-time 10 "$PROM/-/ready"
check "all 4 scrape targets are up (prometheus, node, cadvisor, grafana)" all_targets_up
check "node-exporter metrics are in Prometheus" \
  sh -c "curl -fsS -G --data-urlencode 'query=node_memory_MemTotal_bytes' '$PROM/api/v1/query' | grep -q '\"value\"'"
check "cAdvisor reports per-container metrics with compose labels" \
  sh -c "curl -fsS -G --data-urlencode 'query=container_memory_working_set_bytes{container_label_com_docker_compose_service=\"prometheus\"}' '$PROM/api/v1/query' | grep -q '\"value\"'"
check "alert rules are loaded" sh -c "curl -fsS '$PROM/api/v1/rules' | grep -q '\"name\":\"TargetDown\"'"

check "Grafana /api/health reports database ok" \
  sh -c "curl -fsS --max-time 10 '$GRAFANA/api/health' | grep -q '\"database\": *\"ok\"'"
check "Grafana rejects anonymous API access" \
  sh -c "test \"\$(curl -s -w '\n%{http_code}' --max-time 10 '$GRAFANA/api/datasources' | tail -n1)\" = 401"
check "Prometheus datasource is provisioned and healthy" \
  sh -c "curl -fsS --max-time 10 -u '$AUTH' '$GRAFANA/api/datasources/uid/prometheus/health' | grep -q '\"status\":\"OK\"'"
check "'Host & Containers' dashboard is provisioned" \
  sh -c "curl -fsS --max-time 10 -u '$AUTH' '$GRAFANA/api/dashboards/uid/host-and-containers' | grep -q '\"title\":\"Host \\\\u0026 Containers\"\\|\"title\":\"Host & Containers\"'"

check "node-exporter and cAdvisor are not published on the host" \
  sh -c '! docker compose ps --format "{{.Ports}}" node-exporter cadvisor | grep -q -- "->"'
