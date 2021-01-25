#!/bin/sh

set -exuf

PERSONAL_ACCESS_TOKEN_FILE="/usr/share/secrets/PERSONAL_ACCESS_TOKEN"

# Wait until we have an axiom access token
until [ -f "${PERSONAL_ACCESS_TOKEN_FILE}" ]; do sleep 0.1; done

# Export the env
AXM_TOKEN=$(cat "${PERSONAL_ACCESS_TOKEN_FILE}")
export AXM_TOKEN

exec "$@"
