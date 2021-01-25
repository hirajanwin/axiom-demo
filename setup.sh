#!/bin/sh

set -exuf

# Env variables
AXIOM_DEPLOYMENT_URL="http://axiom-core:80"
AXIOM_USER="demo@axiom.co"
AXIOM_PASSWORD="axiom-d3m0"
PERSONAL_ACCESS_TOKEN="" # set by get_personal_access_token

# Log to stderr
log () {
    echo "$@" >&2
}

# Create a dataset
# $1 = dataset name
# $2 = description
create_dataset () { 
	curl -s -X POST \
		-H 'Content-Type: application/json' \
		-H "Authorization: Bearer ${PERSONAL_ACCESS_TOKEN}" \
		--data "{\"name\":\"${1}\",\"description\":\"${2}\"}" \
		"${AXIOM_DEPLOYMENT_URL}/api/v1/datasets"
}

# Initialize deployment (will error if already initialized)
init_deployment () {
	INIT_RES=$(curl -s -X POST \
		-H 'Content-Type: application/json' \
		--data "{\"org\":\"Demo\",\"name\":\"Demo User\",\"email\":\"${AXIOM_USER}\",\"password\":\"${AXIOM_PASSWORD}\"}" \
		"${AXIOM_DEPLOYMENT_URL}/auth/init")
	INIT_ERROR=$(echo "${INIT_RES}" | jq -r .error)
	# INIT_ERROR is one of
	# * `null` if no JSON is returned
	# * `` if JSON is returned but no error field (or empty)
	# * `<error>` if an error is returned
	if [ "${INIT_ERROR}" != "" ] && [ "${INIT_ERROR}" != "null" ]; then
		log "Could not initialize deployment (already set up?): ${INIT_ERROR}"
	fi
}

# Log in, create new personal access token, logout
get_personal_access_token () {
	TOKEN_NAME="Demo"

	SESSION_RES=$(curl -s -c - -X POST \
		-H 'Content-Type: application/json' \
		--data "{\"email\":\"${AXIOM_USER}\",\"password\":\"${AXIOM_PASSWORD}\"}" \
		"${AXIOM_DEPLOYMENT_URL}/auth/signin/credentials")
	SESSION=$(echo "${SESSION_RES}" | grep axiom.sid | awk '{ print $7 }')

	# Check if we already have a token
	PERSONAL_ACCESS_TOKENS_RES=$(curl -s \
		--cookie "axiom.sid=${SESSION}" \
		"${AXIOM_DEPLOYMENT_URL}/api/v1/tokens/personal")
	PERSONAL_ACCESS_TOKEN_ID=$(echo "${PERSONAL_ACCESS_TOKENS_RES}" | jq -r ".[] | select(.name == \"${TOKEN_NAME}\") | .id")

	# Create one if we don't already have one
	if [ -z "${PERSONAL_ACCESS_TOKEN_ID}" ]; then
		PERSONAL_ACCESS_TOKEN_ID_RES=$(curl -s -X POST \
			-H 'Content-Type: application/json' \
			-H 'X-Axiom-Org-ID: axiom' \
			--cookie "axiom.sid=${SESSION}" \
			--data "{\"id\":\"new\",\"name\":\"${TOKEN_NAME}\",\"description\":\"This is the token automatically created by axiom-demo and used for ingestion\",\"scopes\":[]}" \
			"${AXIOM_DEPLOYMENT_URL}/api/v1/tokens/personal")
		PERSONAL_ACCESS_TOKEN_ID=$(echo "${PERSONAL_ACCESS_TOKEN_ID_RES}"| jq -r .id)
	fi

	PERSONAL_ACCESS_TOKEN_RES=$(curl -s \
		--cookie "axiom.sid=${SESSION}" \
		"${AXIOM_DEPLOYMENT_URL}/api/v1/tokens/personal/${PERSONAL_ACCESS_TOKEN_ID}/token")
	PERSONAL_ACCESS_TOKEN=$(echo "${PERSONAL_ACCESS_TOKEN_RES}" | jq -r .token)

	curl -s --cookie "axiom.sid=${SESSION}" "${AXIOM_DEPLOYMENT_URL}/logout"
}

main () {
	log "Installing dependencies"
	apk add --no-cache curl jq

	log "Waiting for ${AXIOM_DEPLOYMENT_URL} to be reachable"
	while ! curl -s "${AXIOM_DEPLOYMENT_URL}"; do
	  sleep 0.1
	done

	log "Initializing deployment"
	init_deployment

	log "Getting personal access token"
	get_personal_access_token

	log "Creating datasets"
	create_dataset "postgres-logs" "Logs from your local postgres container"
	create_dataset "postgres-metrics" "Metrics from your local postgres container"

	echo "${PERSONAL_ACCESS_TOKEN}" > /usr/share/secrets/PERSONAL_ACCESS_TOKEN
}

main # call main function

