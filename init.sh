#!/bin/sh

set -exuf

HOSTNAME=axiom-core
PORT=80
DEPLOYMENT_URL="http://${HOSTNAME}:${PORT}"

log() {
    echo "$@" >&2
}

log "Installing dependencies"
apk add --no-cache curl jq

echo "Waiting for ${HOSTNAME}:${PORT} to be up"
while ! nc -z "${HOSTNAME}" "${PORT}"; do
  sleep 0.1
done

sleep 0.5 # Wait another half second to make sure the HTTP server is ready

log "Initializing deployment"
INIT_ERROR=$(curl -s -X POST \
	-H 'Content-Type: application/json' \
	--data '{"org":"Demo","name":"Demo User","email":"demo@axiom.co","password":"axiom-d3m0"}' \
	"${DEPLOYMENT_URL}/auth/init" | jq -r .error)
# INIT_ERROR is one of
# * `null` if no JSON is returned
# * `` if JSON is returned but no error field (or empty)
# * `<error>` if an error is returned
if [ "${INIT_ERROR}" != "" ] && [ "${INIT_ERROR}" != "null" ]; then
	log "Could not initialize deployment (already set up?): ${INIT_ERROR}"
	exit 1
fi

log "Login and get session"
SESSION=$(curl -s -c - -X POST \
	-H 'Content-Type: application/json' \
	--data '{"email":"demo@axiom.co","password":"axiom-d3m0"}' \
	"${DEPLOYMENT_URL}/auth/signin/credentials" \
	| grep axiom.sid \
	| awk '{ print $7 }')

log "Create personal access token"
PERSONAL_ACCESS_TOKEN_ID=$(curl -s -X POST \
	-H 'Content-Type: application/json' \
	--cookie "axiom.sid=${SESSION}" \
	--data '{"id":"new","name":"Demo","description":"This is the token automatically created by init.sh","scopes":[]}' \
	"${DEPLOYMENT_URL}/api/v1/tokens/personal" | jq -r .id)

log "Get personal access token"
AXIOM_ACCESS_TOKEN=$(curl -s \
	--cookie "axiom.sid=${SESSION}" \
	"${DEPLOYMENT_URL}/api/v1/tokens/personal/${PERSONAL_ACCESS_TOKEN_ID}/token" | jq -r .token)

log "Logout"
curl -s --cookie "axiom.sid=${SESSION}" "${DEPLOYMENT_URL}/logout"

log "Creating dataset"
curl -s -X POST \
	-H 'Content-Type: application/json' \
	-H "Authorization: Bearer ${AXIOM_ACCESS_TOKEN}" \
	--data '{"name":"Postgres","description":"Postgres logs"}' \
	"${DEPLOYMENT_URL}/api/v1/datasets"
