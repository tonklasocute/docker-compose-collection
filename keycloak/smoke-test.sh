#!/usr/bin/env bash
# Smoke test against the running stack (`make up` first): health, the imported
# demo realm, a client-credentials token, and a full browser-style login
# (authorization code + PKCE) done with curl.
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

set -a
# shellcheck disable=SC1091
. ./.env
set +a

KC="http://$(docker compose port keycloak 8080)"
PUBLIC_URL="${KEYCLOAK_URL:-http://localhost:${KEYCLOAK_PORT:-8080}}"
PUBLIC_URL="${PUBLIC_URL%/}"
REALM="$KC/realms/demo"
OIDC="$REALM/protocol/openid-connect"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

check "management endpoint reports ready" docker compose exec -T keycloak bash -c '
  exec 3<>/dev/tcp/127.0.0.1/9000 &&
  printf "GET /health/ready HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n" >&3 &&
  head -n1 <&3 | grep -q " 200 "'
check "demo realm was imported (OIDC discovery, issuer = KEYCLOAK_URL)" \
  sh -c "curl -fsS --max-time 10 '$REALM/.well-known/openid-configuration' | grep -q '\"issuer\":\"$PUBLIC_URL/realms/demo\"'"

check "admin can get a token from the master realm" sh -c "
  curl -fsS --max-time 10 '$KC/realms/master/protocol/openid-connect/token' \
    -d grant_type=password -d client_id=admin-cli \
    --data-urlencode 'username=$KEYCLOAK_ADMIN' --data-urlencode 'password=$KEYCLOAK_ADMIN_PASSWORD' |
  grep -q access_token"

check "demo-service gets a token with client credentials" sh -c "
  curl -fsS --max-time 10 '$OIDC/token' -d grant_type=client_credentials \
    -u 'demo-service:$DEMO_CLIENT_SECRET' | grep -q access_token"
check "a wrong client secret is rejected (401)" sh -c "
  test \"\$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 '$OIDC/token' \
    -d grant_type=client_credentials -u demo-service:wrong)\" = 401"

# Authorization code + PKCE for the public client demo-app, as a browser would:
# open the login page, submit the form, catch the redirect, exchange the code.
# This goes through the public URL: the login form posts there, and the
# session cookies are bound to its host. --connect-to sends those requests to
# the published port, even if something else answers on localhost over IPv6.
pub=${PUBLIC_URL#*://}
pub=${pub%%/*}
[[ "$pub" == *:* ]] || pub="$pub:80"
route=(--connect-to "$pub:${KC#http://}")
login() {
  local verifier challenge redirect=http://localhost:3000/callback page action location code token
  verifier=$(openssl rand -hex 32)
  challenge=$(printf %s "$verifier" | openssl dgst -sha256 -binary | openssl base64 -A | tr '+/' '-_' | tr -d '=')
  page=$(curl -fsS --max-time 10 "${route[@]}" -c "$TMP/jar" -G "$PUBLIC_URL/realms/demo/protocol/openid-connect/auth" \
    -d client_id=demo-app -d response_type=code -d scope=openid \
    --data-urlencode "redirect_uri=$redirect" \
    -d code_challenge="$challenge" -d code_challenge_method=S256)
  action=$(grep -o 'action="[^"]*"' <<<"$page" | head -n1 | sed 's/^action="//; s/"$//; s/&amp;/\&/g')
  [[ -n "$action" ]] || { echo "no login form found"; return 1; }
  location=$(curl -sS --max-time 10 "${route[@]}" -b "$TMP/jar" -o /dev/null -w '%{redirect_url}' "$action" \
    -d username=demo --data-urlencode "password=$DEMO_USER_PASSWORD" -d credentialId=)
  code=$(sed -n 's/.*[?&]code=\([^&]*\).*/\1/p' <<<"$location")
  [[ -n "$code" ]] || { echo "login did not redirect with a code: '$location'"; return 1; }
  token=$(curl -fsS --max-time 10 "$OIDC/token" -d grant_type=authorization_code -d client_id=demo-app \
    --data-urlencode "redirect_uri=$redirect" -d code="$code" -d code_verifier="$verifier")
  grep -q '"id_token"' <<<"$token" || { echo "$token"; return 1; }
}
check "user demo logs in via authorization code + PKCE" login

check "keycloak runs as non-root (uid 1000)" \
  sh -c 'test "$(docker compose exec -T keycloak id -u)" = 1000'
check "port 8080 is published on 127.0.0.1" sh -c 'docker compose port keycloak 8080 | grep -q "^127.0.0.1:"'
check "postgres is not published to the host" \
  sh -c 'test -z "$(docker compose ps postgres --format "{{range .Publishers}}{{if .PublishedPort}}{{.PublishedPort}}{{end}}{{end}}")"'
