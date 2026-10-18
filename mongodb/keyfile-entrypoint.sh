#!/usr/bin/env bash
# Wraps the official entrypoint to create the replica-set keyfile.
#
# A replica set with auth enabled needs a shared keyfile that is readable only
# by mongod (mode 400). A bind-mounted file can't guarantee that (on Docker
# Desktop it shows up as 0777 and mongod refuses it), so we generate a random
# one inside the config volume on first start and reuse it afterwards.
set -euo pipefail

KEYFILE=/data/configdb/keyfile
if [[ ! -s "$KEYFILE" ]]; then
  head -c 756 /dev/urandom | base64 -w 0 >"$KEYFILE"
fi
chown mongodb:mongodb "$KEYFILE"
chmod 400 "$KEYFILE"

exec docker-entrypoint.sh "$@"
