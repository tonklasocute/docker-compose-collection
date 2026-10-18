#!/usr/bin/env bash
# Smoke test against the running stack (`make up`, optionally `make dev`).
# test-profiles: dev
# shellcheck disable=SC2016  # $VARS in single quotes expand in the sh -c child
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

API="http://$(docker compose port api 8080)"

# curl that prints the body, then the status code on its own last line
req() { curl -s --max-time 10 -w '\n%{http_code}' -H 'Content-Type: application/json' "$@"; }
expect() { # expect <status> <curl args...>: fail unless the status matches
  local want=$1 out code
  shift
  out=$(req "$@")
  code=$(tail -n1 <<<"$out")
  [[ "$code" == "$want" ]] || { echo "want $want, got $code: $(sed '$d' <<<"$out")"; return 1; }
  sed '$d' <<<"$out"
}

check "migrate container applied migrations and exited 0" \
  sh -c 'docker compose ps -a --format "{{.Service}} {{.State}} {{.ExitCode}}" migrate | grep -qx "migrate exited 0"'
check "GET /health reports ok with the baked-in version" \
  sh -c "curl -fsS --max-time 10 '$API/health' | grep -q '\"status\":\"ok\".*\"version\":\"'"

created=$(expect 201 -X POST "$API/api/v1/todos" -d '{"title":"smoke test todo"}') || { echo "  ✗ POST /api/v1/todos: $created"; exit 1; }
id=$(grep -o '"id":[0-9]*' <<<"$created" | cut -d: -f2)
echo "  ✓ POST /api/v1/todos creates todo #$id"

check "GET /api/v1/todos/$id returns it" expect 200 "$API/api/v1/todos/$id"
check "PATCH /api/v1/todos/$id marks it done" \
  sh -c "$(declare -f req expect); expect 200 -X PATCH '$API/api/v1/todos/$id' -d '{\"done\":true}' | grep -q '\"done\":true'"
check "GET /api/v1/todos lists it" sh -c "$(declare -f req expect); expect 200 '$API/api/v1/todos' | grep -q '\"id\":$id'"
check "invalid input is rejected with 422" expect 422 -X POST "$API/api/v1/todos" -d '{"title":"  "}'
check "DELETE /api/v1/todos/$id returns 204" expect 204 -X DELETE "$API/api/v1/todos/$id"
check "GET after delete returns 404" expect 404 "$API/api/v1/todos/$id"

check "api runs as non-root with a read-only filesystem and no capabilities" sh -c '
  c=$(docker compose ps -q api)
  test "$(docker inspect -f "{{.Config.User}}" "$c")" = "65532:65532" &&
  test "$(docker inspect -f "{{.HostConfig.ReadonlyRootfs}}" "$c")" = true &&
  docker inspect -f "{{.HostConfig.CapDrop}}" "$c" | grep -q ALL'

if running api-dev; then
  DEV="http://$(docker compose port api-dev 8080)"
  check "api-dev (air) serves /health" curl -fsS --max-time 10 "$DEV/health"

  # Hot reload: add a Go file to the bind-mounted source, wait for air to
  # rebuild, then remove it again (air rebuilds back to the original).
  marker="reloaded-$RANDOM"
  reload_file=internal/httpapi/zz_smoke_reload.go
  trap 'rm -f "$reload_file"' EXIT
  printf 'package httpapi\n\nfunc init() { Version = "%s" }\n' "$marker" >"$reload_file"
  hot_reloaded() {
    for _ in $(seq 1 45); do
      curl -fsS --max-time 5 "$DEV/health" 2>/dev/null | grep -q "$marker" && return 0
      sleep 2
    done
    docker compose logs --tail=30 api-dev
    return 1
  }
  check "editing a .go file hot-reloads api-dev" hot_reloaded
fi
