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

# mongosh as the app user, over the network via the service name with the
# replica-set URL a real client would use
app_eval() {
  docker compose exec -T -e JS="$1" mongodb sh -c \
    'mongosh --quiet "mongodb://$APP_DB_USER:$APP_DB_PASSWORD@mongodb:27017/$APP_DB_NAME?replicaSet=$MONGO_REPLICA_SET" --eval "$JS"'
}

check "replica set is initiated and this node is PRIMARY" \
  docker compose exec -T mongodb sh -c \
  'mongosh --quiet -u "$MONGO_INITDB_ROOT_USERNAME" -p "$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase admin --eval "quit(rs.status().myState === 1 ? 0 : 1)"'

check "app user reads the sample collection" \
  app_eval 'quit(db.notes.countDocuments() >= 1 ? 0 : 1)'

check "multi-document transaction commits" app_eval '
  const s = db.getMongo().startSession();
  const notes = s.getDatabase(db.getName()).notes;
  s.startTransaction();
  notes.insertOne({ body: "tx-1" });
  notes.insertOne({ body: "tx-2" });
  s.commitTransaction();
  const n = db.notes.countDocuments({ body: { $in: ["tx-1", "tx-2"] } });
  db.notes.deleteMany({ body: { $in: ["tx-1", "tx-2"] } });
  quit(n === 2 ? 0 : 1)'

check "app user cannot read other databases" \
  app_eval 'try { db.getSiblingDB("admin").system.users.findOne(); quit(1) } catch (e) { quit(0) }'

check "port 27017 is published on 127.0.0.1" \
  sh -c 'docker compose port mongodb 27017 | grep -q "^127.0.0.1:"'

if running mongo-express; then
  port=$(docker compose port mongo-express 8081)
  check "mongo-express rejects requests without credentials" \
    sh -c "test \"\$(curl -s -w '\n%{http_code}' --max-time 10 http://$port/ | tail -n1)\" = 401"
  check "mongo-express lists the app database" \
    sh -c "curl -fsS --max-time 10 -u \"\$(grep ^MONGO_EXPRESS_USER= .env | cut -d= -f2):\$(grep ^MONGO_EXPRESS_PASSWORD= .env | cut -d= -f2)\" http://$port/ | grep -q '>app<\\|/db/app'"
fi
