#!/bin/sh
# Runs inside the rabbitmq container as a compose post_start hook: waits for
# the HTTP API, then imports definitions.json into the vhost. Imports are
# idempotent, so this runs on every `docker compose up`.
#
# rabbitmqadmin reads credentials and the vhost from the RABBITMQADMIN_*
# environment. (It's a small HTTP client, much lighter than starting an Erlang
# VM for rabbitmq-diagnostics once a second.)
set -eu

i=0
until rabbitmqadmin show overview >/dev/null 2>&1; do
  i=$((i + 1))
  if [ "$i" -ge 120 ]; then
    echo "import-definitions: RabbitMQ did not start within 120s" >&2
    exit 1
  fi
  sleep 1
done

rabbitmqadmin definitions import_into_vhost --file /etc/rabbitmq/definitions.json
