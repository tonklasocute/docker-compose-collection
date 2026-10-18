#!/usr/bin/env bash
# One-shot setup for the secured Elasticsearch + Kibana stack.
#
#   1. Creates a CA and an HTTPS certificate for Elasticsearch (first run only)
#   2. Generates a random kibana_system password and Kibana encryption keys
#      into kibana.env (first run only) - nothing to put in .env
#   3. Waits for Elasticsearch, then sets the kibana_system password via the API
#
# Everything lives in the shared `certs` volume; the healthcheck in
# compose.yaml reports healthy as soon as the certificates exist, which is
# what lets Elasticsearch start while this script is still waiting for it.
set -euo pipefail

CERTS=/usr/share/elasticsearch/config/certs
CA="$CERTS/ca/ca.crt"
ES_URL=https://elasticsearch:9200

log() { echo "[setup] $*"; }

if [[ ! -f "$CERTS/ca/ca.crt" ]]; then
  log "creating certificate authority"
  bin/elasticsearch-certutil ca --silent --pem --days "${CERT_DAYS:-1095}" -out "$CERTS/ca.zip"
  unzip -oq "$CERTS/ca.zip" -d "$CERTS" && rm "$CERTS/ca.zip"
fi

if [[ ! -f "$CERTS/elasticsearch/elasticsearch.crt" ]]; then
  log "creating certificate for elasticsearch, localhost, 127.0.0.1"
  cat >"$CERTS/instances.yml" <<'EOF'
instances:
  - name: elasticsearch
    dns: [elasticsearch, localhost]
    ip: [127.0.0.1]
EOF
  bin/elasticsearch-certutil cert --silent --pem --days "${CERT_DAYS:-1095}" \
    --ca-cert "$CERTS/ca/ca.crt" --ca-key "$CERTS/ca/ca.key" \
    --in "$CERTS/instances.yml" -out "$CERTS/certs.zip"
  unzip -oq "$CERTS/certs.zip" -d "$CERTS" && rm "$CERTS/certs.zip" "$CERTS/instances.yml"
fi

random() { head -c 64 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c "$1"; }

if [[ ! -f "$CERTS/kibana.env" ]]; then
  log "generating kibana_system password and Kibana encryption keys"
  {
    echo "ELASTICSEARCH_PASSWORD=$(random 32)"
    echo "XPACK_SECURITY_ENCRYPTIONKEY=$(random 32)"
    echo "XPACK_ENCRYPTEDSAVEDOBJECTS_ENCRYPTIONKEY=$(random 32)"
    echo "XPACK_REPORTING_ENCRYPTIONKEY=$(random 32)"
  } >"$CERTS/kibana.env"
fi

# Elasticsearch and Kibana run as uid 1000, group 0; keys stay private.
chown -R 1000:0 "$CERTS"
find "$CERTS" -type d -exec chmod 750 {} +
find "$CERTS" -type f -exec chmod 640 {} +

log "waiting for elasticsearch"
until curl -s --cacert "$CA" -o /dev/null -w '%{http_code}' "$ES_URL" | grep -q 401; do sleep 2; done

KIBANA_PASSWORD=$(sed -n 's/^ELASTICSEARCH_PASSWORD=//p' "$CERTS/kibana.env")
log "setting kibana_system password"
until curl -s --cacert "$CA" -u "elastic:${ELASTIC_PASSWORD}" \
  -H 'Content-Type: application/json' -X POST "$ES_URL/_security/user/kibana_system/_password" \
  -d "{\"password\":\"${KIBANA_PASSWORD}\"}" | grep -q '^{}'; do
  sleep 2
done

log "done"
