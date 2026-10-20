#!/usr/bin/env bash
# Static checks for the whole repo. CI runs exactly this script.
#
#   - every template has the required files
#   - compose files: no `version:` key, no `latest`/untagged images, valid config
#   - shellcheck, hadolint, yamllint (local binary if installed, else a pinned
#     Docker image, so nothing needs to be installed to run this)
#
# Usage: scripts/lint.sh [structure|compose|shell|docker|yaml ...]   (default: all)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SHELLCHECK_IMAGE="koalaman/shellcheck:v0.11.0"
HADOLINT_IMAGE="hadolint/hadolint:v2.15.1"
YAMLLINT_IMAGE="pipelinecomponents/yamllint:0.35.27"
REQUIRED_FILES=(compose.yaml .env.example README.md Makefile smoke-test.sh)

errors=0
fail() { printf '  \e[31m✗\e[0m %s\n' "$*"; errors=$((errors + 1)); }
ok() { printf '  \e[32m✓\e[0m %s\n' "$*"; }
section() { printf '\n\e[1m%s\e[0m\n' "$*"; }

mapfile -t TEMPLATES < <(for d in */compose.yaml; do dirname "$d"; done | sort)

# Run a linter from PATH, or from its Docker image with the repo mounted at /repo.
run_tool() {
  local bin=$1 image=$2
  shift 2
  if command -v "$bin" >/dev/null 2>&1; then
    "$bin" "$@"
  else
    MSYS_NO_PATHCONV=1 docker run --rm -v "$ROOT:/repo" -w /repo --entrypoint "$bin" "$image" "$@"
  fi
}

check_structure() {
  section "Template structure"
  for t in "${TEMPLATES[@]}"; do
    local missing=()
    for f in "${REQUIRED_FILES[@]}"; do [[ -f "$t/$f" ]] || missing+=("$f"); done
    if [[ ${#missing[@]} -eq 0 ]]; then ok "$t"; else fail "$t: missing ${missing[*]}"; fi
  done
}

check_compose() {
  section "Compose files"
  for t in "${TEMPLATES[@]}"; do
    local f="$t/compose.yaml" bad=0 out c files=("$t/compose.yaml")
    # The optional test overlay is validated together with the main file
    [[ -f "$t/compose.test.yaml" ]] && files+=("$t/compose.test.yaml")
    local dc=(docker compose --project-directory "$t" --env-file "$t/.env.example" --profile '*')
    for c in "${files[@]}"; do
      dc+=(-f "$c")
      if grep -qE '^version:' "$c"; then fail "$c: remove the obsolete top-level 'version:' key"; bad=1; fi
      # Images must be literal tags in the file (Dependabot updates them there)...
      if grep -qE '^[[:space:]]+image:.*\$\{' "$c"; then fail "$c: don't build image tags from variables"; bad=1; fi
    done
    if ! out=$("${dc[@]}" config --quiet 2>&1); then
      fail "$f: docker compose config failed"; printf '      %s\n' "${out//$'\n'/$'\n      '}"; bad=1
    else
      # ...and every resolved image (built ones excluded) needs an explicit version
      while read -r img; do
        [[ "$img" == "${COMPOSE_PROJECT_NAME:-$t}"-* || "$img" == "$t"-* ]] && continue
        if [[ "${img##*/}" != *:* || "$img" == *:latest ]]; then
          fail "$f: image '$img' must be pinned to an explicit version"; bad=1
        fi
      done < <("${dc[@]}" config --images)
    fi
    [[ $bad -eq 0 ]] && ok "$t"
  done
}

check_shell() {
  section "shellcheck"
  mapfile -t files < <(git ls-files --cached --others --exclude-standard '*.sh' | sort)
  if run_tool shellcheck "$SHELLCHECK_IMAGE" -x "${files[@]}"; then ok "${#files[@]} scripts"; else fail "shellcheck"; fi
}

check_docker() {
  section "hadolint"
  mapfile -t files < <(git ls-files --cached --others --exclude-standard '*Dockerfile*' | sort)
  if [[ ${#files[@]} -eq 0 ]]; then ok "no Dockerfiles"; return; fi
  if run_tool hadolint "$HADOLINT_IMAGE" "${files[@]}"; then ok "${#files[@]} Dockerfiles"; else fail "hadolint"; fi
}

check_yaml() {
  section "yamllint"
  if run_tool yamllint "$YAMLLINT_IMAGE" --strict -c .yamllint.yaml .; then ok "yaml"; else fail "yamllint"; fi
}

checks=("$@")
[[ ${#checks[@]} -eq 0 ]] && checks=(structure compose shell docker yaml)
for c in "${checks[@]}"; do "check_$c"; done

echo
if [[ $errors -gt 0 ]]; then
  printf '\e[31m%d problem(s) found\e[0m\n' "$errors"
  exit 1
fi
printf '\e[32mAll checks passed\e[0m\n'
