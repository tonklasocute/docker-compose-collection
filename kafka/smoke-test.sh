#!/usr/bin/env bash
# Smoke test against the running stack (`make up` or `make tools` first).
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
kexec() { docker compose exec -T kafka "$@"; }
env_value() { grep "^$1=" .env | cut -d= -f2-; }

TOPIC="smoke-test-$RANDOM"
MESSAGE="hello-$RANDOM-$(date +%s)"

check "broker is a KRaft controller with quorum" \
  sh -c 'docker compose exec -T kafka /opt/kafka/bin/kafka-metadata-quorum.sh --bootstrap-server kafka:29092 describe --status | grep -q "LeaderId:"'

first_topic=$(env_value KAFKA_TOPICS | cut -d, -f1)
if [[ -n "$first_topic" ]]; then
  check "kafka-init created topic '$first_topic'" \
    sh -c "docker compose exec -T kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:29092 --list | grep -qx '$first_topic'"
fi

check "create topic $TOPIC" \
  kexec /opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:29092 --create --topic "$TOPIC" --partitions 1 --replication-factor 1

# Produce through the EXTERNAL listener (what host apps use), consume through
# INTERNAL (what other containers use): exercises both advertised listeners.
check "produce a message via the external listener" \
  sh -c "echo '$MESSAGE' | docker compose exec -T kafka /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server localhost:9092 --topic '$TOPIC'"

check "consume the same message via the internal listener" \
  sh -c "docker compose exec -T kafka /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server kafka:29092 --topic '$TOPIC' --from-beginning --max-messages 1 --timeout-ms 20000 | grep -qx '$MESSAGE'"

kexec /opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:29092 --delete --topic "$TOPIC" >/dev/null 2>&1 || true

check "port 9092 is published on 127.0.0.1" \
  sh -c 'docker compose port kafka 9092 | grep -q "^127.0.0.1:"'

if running kafka-ui; then
  base="http://$(docker compose port kafka-ui 8080)"
  # No temp files for curl: native Windows curl can't open /dev/null or /tmp
  # paths, so read the status code from -w and the cookie from the headers.
  ui_unauthenticated() {
    local code
    code=$(curl -s --max-time 10 -w '\n%{http_code}' "$base/api/clusters" | tail -n1)
    [[ "$code" == 302 || "$code" == 401 ]] || { echo "got HTTP $code"; return 1; }
  }
  # A successful login redirects to / (relative or absolute URL), a failed one
  # to /login?error. Diagnostics go to stderr: stdout is discarded below.
  ui_login() {
    local headers
    for _ in 1 2 3 4 5; do
      headers=$(curl -s --max-time 10 -D - \
        --data-urlencode "username=$(env_value KAFKA_UI_USER)" \
        --data-urlencode "password=$(env_value KAFKA_UI_PASSWORD)" "$base/login")
      if grep -Eqi '^location: (https?://[^/]+)?/'$'\r''?$' <<<"$headers"; then
        SESSION=$(sed -n 's/^set-cookie: \(SESSION=[^;]*\).*/\1/Ip' <<<"$headers")
        [[ -n "$SESSION" ]] && return 0
      fi
      sleep 2
    done
    echo "$headers" >&2
    return 1
  }
  ui_cluster_online() {
    local body
    body=$(curl -fsS --max-time 10 -H "Cookie: $SESSION" "$base/api/clusters")
    if ! grep -q '"status":"ONLINE"' <<<"$body" || ! grep -q '"controller":"KRAFT"' <<<"$body"; then
      echo "$body"
      return 1
    fi
  }
  check "Kafka UI requires login" ui_unauthenticated
  # Not via check(): it runs in a subshell and SESSION must survive
  if ui_login >/dev/null; then echo "  ✓ Kafka UI login works"; else echo "  ✗ Kafka UI login works"; exit 1; fi
  check "Kafka UI sees the cluster online" ui_cluster_online
fi
