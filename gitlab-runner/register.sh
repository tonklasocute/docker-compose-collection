#!/usr/bin/env bash
# Register this runner with GitLab, using the Docker executor.
#
# Usage: ./register.sh [--url URL] [--token glrt-...] [--name NAME]
#
# Defaults come from .env (GITLAB_URL, RUNNER_TOKEN, RUNNER_NAME,
# RUNNER_DEFAULT_IMAGE, RUNNER_JOB_MEMORY, RUNNER_CONCURRENT). Create the
# token first in GitLab: Settings > CI/CD > Runners > New runner.
#
# The registration lands in the runner-config volume; a running runner picks
# it up within a few seconds. Registering again adds another [[runners]]
# entry. `make unregister` removes them all.
set -euo pipefail
cd "$(dirname "$0")"
# Git Bash on Windows rewrites /container/paths in arguments; turn that off
export MSYS_NO_PATHCONV=1

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi

while [[ $# -gt 0 ]]; do
  case $1 in
    --url) GITLAB_URL=$2; shift 2 ;;
    --token) RUNNER_TOKEN=$2; shift 2 ;;
    --name) RUNNER_NAME=$2; shift 2 ;;
    -h | --help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1 (see --help)" >&2; exit 2 ;;
  esac
done

if [[ -z "${GITLAB_URL:-}" ]]; then
  echo "error: set GITLAB_URL in .env or pass --url" >&2
  exit 1
fi
if [[ -z "${RUNNER_TOKEN:-}" ]]; then
  echo "error: set RUNNER_TOKEN in .env or pass --token" >&2
  echo "       Create one in GitLab: Settings > CI/CD > Runners > New runner." >&2
  exit 1
fi
if [[ "$RUNNER_TOKEN" != glrt-* ]]; then
  echo "warning: expected a runner authentication token (glrt-...). Legacy" >&2
  echo "         registration tokens are deprecated and may be disabled." >&2
fi
concurrent=${RUNNER_CONCURRENT:-2}
if [[ ! "$concurrent" =~ ^[1-9][0-9]*$ ]]; then
  echo "error: RUNNER_CONCURRENT must be a positive integer, got '$concurrent'" >&2
  exit 1
fi

# The URL and token go in through the environment (CI_SERVER_URL and
# CI_SERVER_TOKEN are read by `gitlab-runner register`), so the token never
# appears in a process list.
export CI_SERVER_URL=$GITLAB_URL CI_SERVER_TOKEN=$RUNNER_TOKEN
run() { docker compose run --rm --no-deps -T -e CI_SERVER_URL -e CI_SERVER_TOKEN "$@"; }

echo "Registering '${RUNNER_NAME:-docker-runner}' with $GITLAB_URL ..."
run runner register \
  --non-interactive \
  --name "${RUNNER_NAME:-docker-runner}" \
  --executor docker \
  --docker-image "${RUNNER_DEFAULT_IMAGE:-alpine:3.24.2}" \
  --docker-memory "${RUNNER_JOB_MEMORY:-2g}" \
  --docker-volumes /cache \
  --request-concurrency "$((concurrent < 4 ? concurrent : 4))"

# `concurrent` is a global setting that register can't set. (The
# request concurrency above lets jobs start while a long poll is open.)
run --entrypoint sh runner -c \
  "sed -i 's/^concurrent = .*/concurrent = $concurrent/' /etc/gitlab-runner/config.toml"

echo
echo "Done: concurrent = $concurrent. Check it with 'make verify'; the runner"
echo "should show as online under Settings > CI/CD > Runners."
