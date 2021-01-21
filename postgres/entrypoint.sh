#!/bin/sh

set -exuf

LOG_DIR=/usr/share/log

touch "${LOG_DIR}/postgres.log"
chmod 777 "${LOG_DIR}/postgres.log"

# Call postgres docker entrypoint
exec /usr/local/bin/docker-entrypoint.sh "$@"
