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
# rabbitmqadmin inside the broker container; credentials and vhost come from
# its RABBITMQADMIN_* environment
admin() { docker compose exec -T rabbitmq rabbitmqadmin "$@"; }
UI="http://$(docker compose port rabbitmq 15672)"

check "node is running with no resource alarms" \
  docker compose exec -T rabbitmq sh -c 'rabbitmq-diagnostics -q check_running && rabbitmq-diagnostics -q check_local_alarms'
check "AMQP listener is up on 5672" docker compose exec -T rabbitmq rabbitmq-diagnostics -q check_port_listener 5672
check "app.events.audit is a quorum queue" sh -c "$(declare -f admin); admin list queues | grep 'app.events.audit' | grep -q quorum"
check "app.events is bound to app.events.audit" sh -c "$(declare -f admin); admin list bindings | grep 'app.events' | grep -q 'app.events.audit'"
check "the guest user does not exist" sh -c "curl -s -o /dev/null -w '%{http_code}' -u guest:guest '$UI/api/overview' | grep -qx 401"

msg="order-$RANDOM"
check "publish to app.events routes to app.events.audit" \
  sh -c "$(declare -f admin); admin publish message -e app.events -k order.created -m '$msg' -p '{\"delivery_mode\":2}' | grep -q 'routed successfully'"
# Quorum queues are replicated logs on disk: the message must survive a restart
check "persistent message survives a broker restart" \
  sh -c 'docker compose restart rabbitmq >/dev/null && docker compose up -d --wait rabbitmq >/dev/null'
check "get returns the message from app.events.audit" sh -c "$(declare -f admin); admin get messages -q app.events.audit | grep -q '$msg'"

check "ports are published on 127.0.0.1 only" sh -c '
  docker compose port rabbitmq 5672 | grep -q "^127.0.0.1:" && docker compose port rabbitmq 15672 | grep -q "^127.0.0.1:"'
check "management UI answers" curl -fsS --max-time 10 -o /dev/null "$UI/"
