#!/usr/bin/env bash
# Smoke test against the running stack (`make up` or `make tools` first).
# shellcheck disable=SC2016  # $VARS in single quotes expand inside the container
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

check "mysql answers SELECT 1 as root" \
  docker compose exec -T mysql sh -c \
  'test "$(MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot -NBe "SELECT 1")" = 1'

check "app user logs in over the network and reads the sample table" \
  docker compose exec -T mysql sh -c \
  'MYSQL_PWD="$MYSQL_PASSWORD" mysql -h mysql -u"$MYSQL_USER" "$MYSQL_DATABASE" -NBe "SELECT COUNT(*) FROM notes" | grep -qx 1'

check "app user cannot see other databases" \
  docker compose exec -T mysql sh -c \
  '! MYSQL_PWD="$MYSQL_PASSWORD" mysql -h mysql -u"$MYSQL_USER" -NBe "SHOW DATABASES" | grep -qx mysql'

check "port 3306 is published on 127.0.0.1" \
  sh -c 'docker compose port mysql 3306 | grep -q "^127.0.0.1:"'

if running adminer; then
  check "Adminer serves its login page" \
    sh -c "curl -fsS --max-time 10 'http://$(docker compose port adminer 8080)/' | grep -qi adminer"
fi
