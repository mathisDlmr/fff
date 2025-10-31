#!/bin/bash

set -e

log() {
  echo "$(date -Iseconds) $*"
}

CLEAN_INTERVAL=${CLEAN_INTERVAL:-300}

if [ -z "$PGWAL_DIR" ]; then
  log "PGWAL_DIR is not correctly set"
  exit 1
fi

while sleep "$CLEAN_INTERVAL"; do
    lastCheckpoint=$(pg_controldata -D /pgdata/pg14/ | grep "REDO WAL file" | awk '{ print $NF }')
    log "Cleaning until $lastCheckpoint"

    if pg_archivecleanup "$PGWAL_DIR" "$lastCheckpoint"; then
      log "pgWAL has been successfully cleaned up"
    else
      log "Unsuccessful attempt to clean up pgWAL"
    fi
done
