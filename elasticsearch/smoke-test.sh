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
# curl inside the elasticsearch container, over HTTPS, verified against our CA
es() {
  docker compose exec -T -e REQ_PATH="$1" -e REQ_ARGS="${2:-}" elasticsearch sh -c \
    'curl -sS --cacert config/certs/ca/ca.crt -u "elastic:$ELASTIC_PASSWORD" $REQ_ARGS "https://localhost:9200$REQ_PATH"'
}
env_value() { grep "^$1=" .env | cut -d= -f2-; }

check "setup container finished successfully" \
  sh -c 'docker compose ps -a --format "{{.Service}} {{.State}} {{.ExitCode}}" setup | grep -qx "setup exited 0"'

check "cluster health is green or yellow over HTTPS" \
  bash -c "$(declare -f es); es /_cluster/health | grep -Eq '\"status\":\"(green|yellow)\"'"

check "anonymous requests are rejected (401)" \
  docker compose exec -T elasticsearch sh -c \
  'test "$(curl -s --cacert config/certs/ca/ca.crt -o /dev/null -w "%{http_code}" https://localhost:9200)" = 401'

check "plain HTTP is refused (TLS only)" \
  docker compose exec -T elasticsearch sh -c '! curl -fs http://localhost:9200 >/dev/null 2>&1'

check "index a document and find it with a search" bash -c "$(declare -f es)
  es '/smoke-test/_doc/1?refresh=true' \"-X PUT -H Content-Type:application/json -d {\\\"msg\\\":\\\"hello-smoke\\\"}\" | grep -q '\"result\":\"created\"' &&
  es '/smoke-test/_search?q=msg:hello-smoke' | grep -q '\"value\":1' &&
  es '/smoke-test' '-X DELETE' | grep -q acknowledged"

check "kibana_system authenticates with the generated password" \
  docker compose exec -T elasticsearch sh -c \
  'pw=$(sed -n "s/^ELASTICSEARCH_PASSWORD=//p" config/certs/kibana.env) &&
   curl -fsS --cacert config/certs/ca/ca.crt -u "kibana_system:$pw" https://localhost:9200/_security/_authenticate | grep -q "\"username\":\"kibana_system\""'

check "port 9200 is published on 127.0.0.1" \
  sh -c 'docker compose port elasticsearch 9200 | grep -q "^127.0.0.1:"'

if running kibana; then
  check "Kibana reports overall status 'available'" \
    sh -c "curl -fsS --max-time 15 -u 'elastic:$(env_value ELASTIC_PASSWORD)' 'http://$(docker compose port kibana 5601)/api/status' | grep -q '\"overall\":{\"level\":\"available\"'"
fi
