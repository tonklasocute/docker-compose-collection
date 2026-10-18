#!/usr/bin/env bash
# Run scripts/test-template.sh for every template and print a pass/fail table.
#
# Usage: scripts/test-all.sh [template ...]     (default: every template)
#
# Environment:
#   SKIP="elasticsearch kafka"   templates to skip
#   LOG_DIR=path                 where per-template logs go (default: .tmp/logs)
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${LOG_DIR:-$ROOT/.tmp/logs}"
mkdir -p "$LOG_DIR"

if [[ $# -gt 0 ]]; then
  templates=("$@")
else
  mapfile -t templates < <(cd "$ROOT" && for d in */compose.yaml; do dirname "$d"; done | sort)
fi

declare -a rows
failed=0
for t in "${templates[@]}"; do
  if [[ " ${SKIP:-} " == *" $t "* ]]; then
    rows+=("$t|SKIP|-")
    continue
  fi
  printf '\n### %s\n' "$t"
  start=$SECONDS
  if "$ROOT/scripts/test-template.sh" "$t" 2>&1 | tee "$LOG_DIR/$t.log"; then
    rows+=("$t|PASS|$((SECONDS - start))s")
  else
    rows+=("$t|FAIL|$((SECONDS - start))s")
    failed=$((failed + 1))
  fi
done

printf '\n%-16s %-6s %s\n' TEMPLATE RESULT TIME
printf '%-16s %-6s %s\n' ---------------- ------ ----
for r in "${rows[@]}"; do
  IFS='|' read -r t res dur <<<"$r"
  printf '%-16s %-6s %s\n' "$t" "$res" "$dur"
done

# Markdown summary for GitHub Actions job pages
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo '| Template | Result | Time |'
    echo '|---|---|---|'
    for r in "${rows[@]}"; do
      IFS='|' read -r t res dur <<<"$r"
      echo "| $t | $res | $dur |"
    done
  } >>"$GITHUB_STEP_SUMMARY"
fi

printf '\n%d template(s) failed. Logs: %s\n' "$failed" "$LOG_DIR"
[[ $failed -eq 0 ]]
