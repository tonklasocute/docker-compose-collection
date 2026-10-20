#!/usr/bin/env bash
# Smoke test against the running stack (`make up` first). Everything goes
# through nginx, the only published port - like a real browser would.
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

BASE="http://$(docker compose port nginx 8080)"

# expect <status> <curl args...>: print the body, fail unless the status matches
expect() {
  local want=$1 out code
  shift
  out=$(curl -s --max-time 15 -w '\n%{http_code}' -H 'Content-Type: application/json' "$@")
  code=$(tail -n1 <<<"$out")
  [[ "$code" == "$want" ]] || { echo "want $want, got $code: $(sed '$d' <<<"$out" | head -c 400)"; return 1; }
  sed '$d' <<<"$out"
}
headers() { curl -s --max-time 10 -D - "$@" | tr -d '\r' | sed '/^$/q'; }

check "nginx answers /nginx-health" expect 200 "$BASE/nginx-health"
check "/api/health is routed to the Go API" bash -c "$(declare -f expect); expect 200 '$BASE/api/health' | grep -q '\"db\":\"ok\"'"

page=$(expect 200 "$BASE/") || { echo "  ✗ GET / : $page"; exit 1; }
echo "  ✓ GET / is server-rendered by Next.js"
for hop in browser nginx next api postgres; do
  check "route map: $hop stop is ok" grep -q "data-hop=\"$hop\" data-status=\"ok\"" <<<"$page"
done

TITLE="smoke-$RANDOM-todo"
created=$(expect 201 -X POST "$BASE/api/v1/todos" -d "{\"title\":\"$TITLE\"}") || { echo "  ✗ POST /api/v1/todos via nginx: $created"; exit 1; }
id=$(grep -o '"id":[0-9]*' <<<"$created" | cut -d: -f2)
echo "  ✓ POST /api/v1/todos via nginx creates todo #$id"
# The todo was written by the browser path (nginx -> api -> postgres); the
# page reads it back through the SSR path (next -> api -> postgres).
check "the new todo appears in the next server render" sh -c "curl -fsS --max-time 15 '$BASE/' | grep -q '$TITLE'"
check "DELETE via nginx returns 204" expect 204 -X DELETE "$BASE/api/v1/todos/$id"

check "security headers are set and the nginx version is hidden" sh -c "
  h=\$($(declare -f headers); headers '$BASE/')
  echo \"\$h\" | grep -qi '^x-content-type-options: nosniff' &&
  echo \"\$h\" | grep -qi '^x-frame-options: deny' &&
  echo \"\$h\" | grep -qi '^referrer-policy:' &&
  echo \"\$h\" | grep -qi '^server: nginx\$' &&
  ! echo \"\$h\" | grep -qi '^x-powered-by'"

asset=$(grep -o '/_next/static/[^"]*\.css' <<<"$page" | head -n1)
check "static assets are served with immutable caching ($asset)" \
  bash -c "$(declare -f headers); headers '$BASE$asset' | grep -qi '^cache-control:.*immutable'"

check "nginx is the only service with a published port" sh -c '
  test "$(docker compose ps --format "{{.Service}} {{.Ports}}" | grep -- "->" | cut -d" " -f1)" = nginx'
check "postgres is on an internal network only" sh -c '
  docker inspect -f "{{range \$k, \$v := .NetworkSettings.Networks}}{{\$k}} {{end}}" "$(docker compose ps -q postgres)" | grep -qv frontend'
# Regression: nginx must re-resolve `web` after it gets a new IP (redeploy)
recreated_web_still_served() {
  docker compose up -d --force-recreate --no-deps --wait web >/dev/null 2>&1
  for _ in $(seq 1 10); do
    [[ "$(curl -s -o "$(dev_null)" -w '%{http_code}' --max-time 10 "$BASE/")" == 200 ]] && return 0
    sleep 2
  done
  echo "nginx still can't reach the recreated web container"
  return 1
}
# native Windows curl can't open /dev/null; NUL works there
dev_null() { case "$(uname -s)" in MINGW* | MSYS* | CYGWIN*) echo NUL ;; *) echo /dev/null ;; esac; }
check "nginx keeps serving after web is recreated (DNS re-resolve)" recreated_web_still_served

check "nginx, web and api run as non-root on read-only filesystems" sh -c '
  for s in nginx web api; do
    c=$(docker compose ps -q $s)
    u=$(docker inspect -f "{{.Config.User}}" "$c")
    [ -n "$u" ] && [ "$u" != root ] && [ "$u" != 0 ] || { echo "$s runs as root"; exit 1; }
    [ "$(docker inspect -f "{{.HostConfig.ReadonlyRootfs}}" "$c")" = true ] || { echo "$s is writable"; exit 1; }
  done'
