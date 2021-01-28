#!/bin/sh

set -exuf

# Env variables
AXIOM_DEPLOYMENT_URL="http://axiom-core:80"
AXIOM_USER="demo@axiom.co"
AXIOM_PASSWORD="axiom-d3m0"
PERSONAL_ACCESS_TOKEN="274dc2a2-5db4-4f8c-92a3-92e33bee92a8"
DASHBOARD_OWNER="" # Set by first call to create_dashboard

# Log to stderr
log () {
    echo "$@" >&2
}

# $1 = name
# $2 = alias
# $3 = description
# $4 = dataset
# $5 = expression
create_vfield () {
	curl -s -X POST \
		-H 'Content-Type: application/json' \
		-H "Authorization: Bearer ${PERSONAL_ACCESS_TOKEN}" \
		--data "{\"name\":\"$1\",\"alias\":\"$2\",\"description\":\"$3\",\"dataset\":\"$4\",\"expression\":\"$4\"}" \
		"${AXIOM_DEPLOYMENT_URL}/api/v1/vfields"
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
create_personal_access_token () {
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

	# Get original personal access token to be able to update it
        ORIGINAL_PERSONAL_ACCESS_TOKEN_RES=$(curl -s \
                --cookie "axiom.sid=${SESSION}" \
                "${AXIOM_DEPLOYMENT_URL}/api/v1/tokens/personal/${PERSONAL_ACCESS_TOKEN_ID}/token")
        ORIGINAL_PERSONAL_ACCESS_TOKEN=$(echo "${ORIGINAL_PERSONAL_ACCESS_TOKEN_RES}" | jq -r .token)

	# Update token in database to make sure it's always the same
	psql -c "UPDATE axm_ui_auth_authtokens SET entity = entity || '{\"Token\":\"${PERSONAL_ACCESS_TOKEN}\", \"ID\":\"${PERSONAL_ACCESS_TOKEN}\"}', id = '${PERSONAL_ACCESS_TOKEN}' WHERE id = '${ORIGINAL_PERSONAL_ACCESS_TOKEN}';" "${POSTGRES_URL}"

	curl -s --cookie "axiom.sid=${SESSION}" "${AXIOM_DEPLOYMENT_URL}/logout"
}

# $1 = file in dashboards/
create_dashboard() {
	# Get dashboard owner once
	if [ -z "${DASHBOARD_OWNER}" ]; then
		DASHBOARD_OWNER_RES=$(curl -s \
			-H "Authorization: Bearer ${PERSONAL_ACCESS_TOKEN}" \
			"${AXIOM_DEPLOYMENT_URL}/api/v1/user")
		DASHBOARD_OWNER=$(echo "${DASHBOARD_OWNER_RES}" | jq -r .id)
	fi

	# Get dashboard payload and replace owner var
	DASHBOARD_PAYLOAD=$(sed "s/\$DASHBOARD_OWNER/${DASHBOARD_OWNER}/g" < "/usr/share/dashboards/${1}")

	# Check if we already have a dashboard with the same name
	DASHBOARD_NAME=$(echo "${DASHBOARD_PAYLOAD}" | jq -r .name)
	DASHBOARDS_RES=$(curl -s \
		-H "Authorization: Bearer ${PERSONAL_ACCESS_TOKEN}" \
		"${AXIOM_DEPLOYMENT_URL}/api/v1/dashboards")
	DASHBOARD_EXISTS=$(echo "${DASHBOARDS_RES}" | jq -r --arg name "${DASHBOARD_NAME}" '.[] | select(.name == $name).name')
	if [ -n "${DASHBOARD_EXISTS}" ]; then
		return # Dashboard with this name already exists, skip
	fi

	# Create dashboard
	curl -s -X POST \
		-H "Authorization: Bearer ${PERSONAL_ACCESS_TOKEN}" \
		-H 'Content-Type: application/json' \
		--data "${DASHBOARD_PAYLOAD}" \
		"${AXIOM_DEPLOYMENT_URL}/api/v1/dashboards"
}

# $1 = name
# $2 = url
create_notifier () {
	# Check if we already have a notifier with the same name
	NOTIFIERS_RES=$(curl -s \
		-H "Authorization: Bearer ${PERSONAL_ACCESS_TOKEN}" \
		"${AXIOM_DEPLOYMENT_URL}/api/v1/notifiers")
	NOTIFIER_EXISTS=$(echo "${NOTIFIERS_RES}" | jq -r --arg name "${1}" '.[] | select(.name == $name).name')
	if [ -n "${NOTIFIER_EXISTS}" ]; then
		return # Notifer with this name already exists, skip
	fi

	curl -s -X POST \
		-H "Authorization: Bearer ${PERSONAL_ACCESS_TOKEN}" \
		-H 'Content-Type: application/json' \
		--data "{\"id\":\"new\",\"name\":\"${1}\",\"properties\":{\"Url\":\"${2}\"},\"type\":\"webhook\"}" \
		"${AXIOM_DEPLOYMENT_URL}/api/v1/notifiers"
}

main () {
	log "Installing dependencies"
	apk add --no-cache curl jq postgresql-client

	log "Waiting for ${AXIOM_DEPLOYMENT_URL} to be reachable"
	while ! curl -s "${AXIOM_DEPLOYMENT_URL}"; do
	  sleep 0.1
	done

	log "Initializing deployment"
	init_deployment

	log "Creating personal access token"
	create_personal_access_token

	log "Creating datasets"
	create_dataset "postgres-logs" "Logs from your local postgres container"
	create_dataset "minio-traces" "Traces from your local minio container"
	create_dataset "http-logs" "Generated http logs from axisynth"
	create_dataset "incoming-webhooks" "Webhooks sent to http://ingest-webhook/ are collected here for testing purposes"

	log "Creating dashboards"
	create_dashboard "minio.json"
	create_dashboard "postgres.json"
	create_dashboard "http.json"

	log "Creating virtual fields"
	create_vfield "statement" "statement" "Extract the sql statement from a log line" "postgres-logs" 'extract("(?s)LOG:[\\\\s]+statement:[\\\\s]+(.+)", 1, message)'

	log "Creating incoming-webhooks notifier"
	create_notifier "incoming-webhooks dataset" "http://ingest-webhook"
}

main # call main function

