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

API="http://$(docker compose port api 3000)"

# expect <status> <curl args...>: print the body, fail unless the status matches
expect() {
  local want=$1 out code
  shift
  out=$(curl -s --max-time 10 -w '\n%{http_code}' -H 'Content-Type: application/json' "$@")
  code=$(tail -n1 <<<"$out")
  [[ "$code" == "$want" ]] || { echo "want $want, got $code: $(sed '$d' <<<"$out")"; return 1; }
  sed '$d' <<<"$out"
}
# x_cache <url>: print the X-Cache response header
x_cache() { curl -s --max-time 10 -D - -o "$(dev_null)" "$1" | tr -d '\r' | sed -n 's/^[Xx]-[Cc]ache: //p'; }
# native Windows curl can't open /dev/null; NUL works there
dev_null() { if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* || "$(uname -s)" == CYGWIN* ]]; then echo NUL; else echo /dev/null; fi; }

check "GET /health reports postgres and redis ok" \
  sh -c "curl -fsS --max-time 10 '$API/health' | grep -q '\"db\":\"ok\",\"redis\":\"ok\"'"

created=$(expect 201 -X POST "$API/api/v1/notes" -d '{"title":"  smoke test  ","body":"hello"}') || {
  echo "  ✗ POST /api/v1/notes: $created"; exit 1; }
id=$(grep -o '"id":"\?[0-9]*' <<<"$created" | grep -o '[0-9]*$')
echo "  ✓ POST /api/v1/notes creates note #$id"
check "title was trimmed by the DTO" grep -q '"title":"smoke test"' <<<"$created"

check "first GET is a cache MISS (read from postgres)" sh -c "test \"\$($(declare -f x_cache dev_null); x_cache '$API/api/v1/notes/$id')\" = MISS"
check "second GET is a cache HIT (served by redis)" sh -c "test \"\$($(declare -f x_cache dev_null); x_cache '$API/api/v1/notes/$id')\" = HIT"
check "PATCH updates the note" bash -c "$(declare -f expect); expect 200 -X PATCH '$API/api/v1/notes/$id' -d '{\"title\":\"edited\"}' | grep -q '\"title\":\"edited\"'"
check "PATCH invalidated the cache (MISS again, new title)" sh -c "
  test \"\$($(declare -f x_cache dev_null); x_cache '$API/api/v1/notes/$id')\" = MISS &&
  curl -fsS '$API/api/v1/notes/$id' | grep -q '\"title\":\"edited\"'"
check "GET /api/v1/notes lists it" bash -c "$(declare -f expect); expect 200 '$API/api/v1/notes?limit=10' | grep -q '\"title\":\"edited\"'"
check "validation: empty title -> 400" expect 400 -X POST "$API/api/v1/notes" -d '{"title":"   "}'
check "validation: unknown field -> 400" expect 400 -X POST "$API/api/v1/notes" -d '{"title":"a","admin":true}'
check "validation: non-numeric id -> 400" expect 400 "$API/api/v1/notes/abc"
check "DELETE returns 204" expect 204 -X DELETE "$API/api/v1/notes/$id"
check "GET after delete returns 404" expect 404 "$API/api/v1/notes/$id"

check "api runs as 'node' with a read-only filesystem and no capabilities" sh -c '
  c=$(docker compose ps -q api)
  test "$(docker inspect -f "{{.Config.User}}" "$c")" = node &&
  test "$(docker inspect -f "{{.HostConfig.ReadonlyRootfs}}" "$c")" = true &&
  docker inspect -f "{{.HostConfig.CapDrop}}" "$c" | grep -q ALL'
check "production image has no npm" sh -c '! docker compose exec -T api sh -c "command -v npm"'

if running api-dev; then
  DEV="http://$(docker compose port api-dev 3000)"
  check "api-dev (nest --watch) serves /health" curl -fsS --max-time 10 "$DEV/health"

  # Watch mode: change src/version.ts, wait for the new value, then restore it
  marker="reloaded-$RANDOM"
  original=$(cat src/version.ts)
  trap 'printf "%s\n" "$original" > src/version.ts' EXIT
  printf "export const VERSION = '%s';\n" "$marker" >src/version.ts
  watch_reloaded() {
    for _ in $(seq 1 45); do
      curl -fsS --max-time 5 "$DEV/health" 2>/dev/null | grep -q "$marker" && return 0
      sleep 2
    done
    docker compose logs --tail=30 api-dev
    return 1
  }
  check "editing src/ recompiles and restarts api-dev" watch_reloaded
fi
