#!/usr/bin/env bash
# Test one template end to end, the same way a user would run it:
#
#   1. copy the template into a scratch dir and create .env from .env.example
#   2. docker compose config     (static validation)
#   3. docker compose up --wait  (every service must report healthy)
#   4. ./smoke-test.sh           (functional check, e.g. SELECT 1, PING, /health)
#   5. docker compose down -v    (always, even on failure)
#
# Usage: scripts/test-template.sh <template> [--keep]
#
# Environment:
#   TEST_PROFILES   comma-separated compose profiles to enable (default: tools)
#   WAIT_TIMEOUT    seconds to wait for healthchecks (default: 300)
#   KEEP=1          same as --keep: leave the stack running for debugging
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAME="${1:-}"
[[ "${2:-}" == "--keep" ]] && KEEP=1
KEEP="${KEEP:-0}"
WAIT_TIMEOUT="${WAIT_TIMEOUT:-300}"

if [[ -z "$NAME" || "$NAME" == "-h" || "$NAME" == "--help" ]]; then
  sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
fi

SRC="$ROOT/$NAME"
for f in compose.yaml .env.example smoke-test.sh; do
  [[ -f "$SRC/$f" ]] || { echo "error: $NAME/$f not found" >&2; exit 2; }
done

if [[ -t 1 ]]; then
  BOLD=$'\e[1m' GREEN=$'\e[32m' RED=$'\e[31m' DIM=$'\e[2m' RESET=$'\e[0m'
else
  BOLD='' GREEN='' RED='' DIM='' RESET=''
fi
step() { printf '%s==> [%s] %s%s\n' "$BOLD" "$NAME" "$*" "$RESET"; }

# Work on a copy so a developer's own .env and running stack are never touched.
WORK="$ROOT/.tmp/test-$NAME"
# (Windows can refuse to delete a directory a shell is still sitting in; the
# copy below overwrites everything that matters, so carry on.)
rm -rf "$WORK" 2>/dev/null || echo "warning: could not fully clean $WORK" >&2
mkdir -p "$WORK"
tar -C "$SRC" --exclude=.env --exclude=node_modules --exclude=.next \
  --exclude=dist --exclude=tmp -cf - . | tar -C "$WORK" -xf -
cp "$WORK/.env.example" "$WORK/.env"
cd "$WORK"
# Git Bash on Windows rewrites /container/paths in arguments; turn that off
export MSYS_NO_PATHCONV=1

export COMPOSE_PROJECT_NAME="dcc-test-$NAME"
export COMPOSE_PROFILES="${TEST_PROFILES-tools}"

cleanup() {
  local code=$?
  if [[ $code -ne 0 ]]; then
    printf '%s--- diagnostics ---%s\n' "$DIM" "$RESET"
    docker compose ps -a || true
    docker compose logs --no-color --tail=60 || true
  fi
  if [[ "$KEEP" == "1" ]]; then
    step "--keep: stack left running (cd $WORK && docker compose down -v)"
  else
    step "tearing down"
    docker compose --profile '*' down -v --remove-orphans --timeout 10 >/dev/null 2>&1 || true
    cd "$ROOT" && rm -rf "$WORK"
  fi
  if [[ $code -eq 0 ]]; then
    printf '%sPASS%s %s (%ss)\n' "$GREEN" "$RESET" "$NAME" "$SECONDS"
  else
    printf '%sFAIL%s %s (%ss)\n' "$RED" "$RESET" "$NAME" "$SECONDS"
  fi
  exit "$code"
}
trap cleanup EXIT

SECONDS=0
step "validating compose file (profiles: ${COMPOSE_PROFILES:-none})"
docker compose config --quiet

# Start from nothing, even if an earlier aborted run left containers behind
docker compose --profile '*' down -v --remove-orphans --timeout 5 >/dev/null 2>&1 || true

step "building and starting (waiting up to ${WAIT_TIMEOUT}s for healthchecks)"
docker compose up -d --build --wait --wait-timeout "$WAIT_TIMEOUT"
docker compose ps --format 'table {{.Service}}\t{{.Status}}\t{{.Ports}}'

step "running smoke test"
./smoke-test.sh
