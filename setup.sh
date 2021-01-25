#!/bin/sh

set -exuf

DEPLOYMENT_URL="http://axiom-core:80"

log() {
    echo "$@" >&2
}

log "Installing dependencies"
apk add --no-cache curl jq

echo "Waiting for ${DEPLOYMENT_URL} to be up"
while ! curl -s "${DEPLOYMENT_URL}"; do
  sleep 0.1
done

log "Initializing deployment"
INIT_RES=$(curl -s -X POST \
	-H 'Content-Type: application/json' \
	--data '{"org":"Demo","name":"Demo User","email":"demo@axiom.co","password":"axiom-d3m0"}' \
	"${DEPLOYMENT_URL}/auth/init")
INIT_ERROR=$(echo "${INIT_RES}" | jq -r .error)
# INIT_ERROR is one of
# * `null` if no JSON is returned
# * `` if JSON is returned but no error field (or empty)
# * `<error>` if an error is returned
if [ "${INIT_ERROR}" != "" ] && [ "${INIT_ERROR}" != "null" ]; then
	log "Could not initialize deployment (already set up?): ${INIT_ERROR}"
	exit 1
fi

log "Logging int and getting session"
SESSION_RES=$(curl -s -c - -X POST \
	-H 'Content-Type: application/json' \
	--data '{"email":"demo@axiom.co","password":"axiom-d3m0"}' \
	"${DEPLOYMENT_URL}/auth/signin/credentials")
SESSION=$(echo "${SESSION_RES}" | grep axiom.sid | awk '{ print $7 }')

log "Creating access token"
PERSONAL_ACCESS_TOKEN_ID_RES=$(curl -s -X POST \
	-H 'Content-Type: application/json' \
	-H 'X-Axiom-Org-ID: axiom' \
	--cookie "axiom.sid=${SESSION}" \
	--data '{"id":"new","name":"Demo","description":"This is the token automatically created by axiom-demo","scopes":[]}' \
	"${DEPLOYMENT_URL}/api/v1/tokens/personal")
PERSONAL_ACCESS_TOKEN_ID=$(echo "${PERSONAL_ACCESS_TOKEN_ID_RES}"| jq -r .id)

log "Getting access token"
PERSONAL_ACCESS_TOKEN_RES=$(curl -s \
	--cookie "axiom.sid=${SESSION}" \
	"${DEPLOYMENT_URL}/api/v1/tokens/personal/${PERSONAL_ACCESS_TOKEN_ID}/token")
PERSONAL_ACCESS_TOKEN=$(echo "${PERSONAL_ACCESS_TOKEN_RES}" | jq -r .token)

log "Logout"
curl -s --cookie "axiom.sid=${SESSION}" "${DEPLOYMENT_URL}/logout"

log "Creating datasets"
curl -s -X POST \
	-H 'Content-Type: application/json' \
	-H "Authorization: Bearer ${PERSONAL_ACCESS_TOKEN}" \
	--data '{"name":"Postgres Logs","description":"Logs from your local postgres container"}' \
	"${DEPLOYMENT_URL}/api/v1/datasets"
curl -s -X POST \
	-H 'Content-Type: application/json' \
	-H "Authorization: Bearer ${PERSONAL_ACCESS_TOKEN}" \
	--data '{"name":"Postgres Metrics","description":"Metrics from your local postgres container"}' \
	"${DEPLOYMENT_URL}/api/v1/datasets"

log "Writing access token to secrets"
echo "${PERSONAL_ACCESS_TOKEN}" > /usr/share/secrets/PERSONAL_ACCESS_TOKEN
