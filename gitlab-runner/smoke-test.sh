#!/usr/bin/env bash
# Smoke test against the running stack (`make up` first).
#
# With the mock-gitlab service running (profile: test), it also registers the
# runner against that fake GitLab API and runs one real job through the
# Docker executor:  docker compose --profile test up -d --wait && make test
# test-profiles: test
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

METRICS="http://$(docker compose port runner 9252)/metrics"

check "runner serves Prometheus metrics" sh -c "curl -fsS --max-time 10 '$METRICS' | grep -q '^gitlab_runner_version_info'"
check "runner can reach the host Docker daemon" docker compose exec -T runner test -S /var/run/docker.sock
check "metrics port is published on 127.0.0.1" sh -c 'docker compose port runner 9252 | grep -q "^127.0.0.1:"'

running mock-gitlab || exit 0

state() { docker compose exec -T mock-gitlab python -c \
  "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8080/-/state').read().decode())"; }

# Remove anything the Docker executor left on the host for the test job
# (its containers and volumes are named runner-<token prefix>-project-1-...)
cleanup_job() {
  docker ps -aq --filter name=runner-smoke-tes-project-1- | xargs -r docker rm -f >/dev/null 2>&1 || true
  docker volume ls -q --filter name=runner-smoke-tes-project-1- | xargs -r docker volume rm -f >/dev/null 2>&1 || true
}
trap cleanup_job EXIT

check "register.sh registers the runner (docker executor)" \
  ./register.sh --url http://mock-gitlab:8080 --token glrt-smoke-test --name smoke
check "config.toml has the docker runner and concurrent from .env" bash -c '
  cfg=$(docker compose exec -T runner cat /etc/gitlab-runner/config.toml)
  grep -q "executor = \"docker\"" <<<"$cfg" &&
  grep -q "url = \"http://mock-gitlab:8080\"" <<<"$cfg" &&
  grep -qx "concurrent = 2" <<<"$cfg"'
check "gitlab-runner verify succeeds" docker compose exec -T runner gitlab-runner verify

job_done() {
  for _ in $(seq 1 90); do
    s=$(state)
    grep -q '"job_state": "\(success\|failed\)"' <<<"$s" && break
    sleep 2
  done
  grep -q '"job_state": "success"' <<<"$s" && grep -q 'smoke-ok 42 alpine-3' <<<"$s" && return 0
  echo "$s"
  docker compose logs --tail=40 runner
  return 1
}
check "a job runs in a container via the Docker executor and succeeds" job_done
