#!/bin/sh

# This script requires curl and jq to be installed.

HOSTNAME=axiom-core
PORT=80
DEPLOYMENT_URL="http://$HOSTNAME:$PORT"

# Wait for axiom-core to be up
while ! nc -z "$HOST" "$PORT"; do
  sleep 0.1
done

# Initialize deployment
curl -s -X POST \
	-H 'Content-Type: application/json' \
	--data '{"org":"Demo","name":"Demo User","email":"demo@axiom.co","password":"axiom-d3m0"}' \
	"$DEPLOYMENT_URL/auth/init"

# Login and get session
SESSION=$(curl -s -c - -X POST \
	-H 'Content-Type: application/json' \
	--data '{"email":"demo@axiom.co","password":"axiom-d3m0"}' \
	"$DEPLOYMENT_URL/auth/signin/credentials" \
	| grep axiom.sid \
	| awk '{ print $7 }')

# Create personal access token
PERSONAL_ACCESS_TOKEN_ID=$(curl -s -X POST \
	-H 'Content-Type: application/json' \
	--cookie "axiom.sid=$SESSION" \
	--data '{"id":"new","name":"Demo","description":"This is the token automatically created by init.sh","scopes":[]}' \
	"$DEPLOYMENT_URL/api/v1/tokens/personal" | jq -r .id)

# Get personal access token
PERSONAL_ACCESS_TOKEN=$(curl -s \
	--cookie "axiom.sid=$SESSION" \
	"$DEPLOYMENT_URL/api/v1/tokens/personal/$PERSONAL_ACCESS_TOKEN_ID/token" | jq -r .token)

# Logout
curl -s --cookie "axiom.sid=$SESSION" \
	"$DEPLOYMENT_URL/logout"

echo "$PERSONAL_ACCESS_TOKEN"
