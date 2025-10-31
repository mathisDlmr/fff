#!/bin/sh

set -eu

TRIES=${TRIES:-1}
TOTAL=${TOTAL:-60}
FAILED=${FAILED:-1}

if [ -z "$PGUSER" ]
then
  echo "[ERROR] PGUSER is missing"
  exit 1
fi

if [ -z "$PGPORT" ]
then
  echo "[ERROR] PGPORT is missing"
  exit 1
fi

if [ -z "$PGPASSWORD" ]
then
  echo "[ERROR] PGPASSWORD is missing"
  exit 1
fi

if [ -z "$PGHOST" ]
then
  echo "[ERROR] PGHOST is missing"
  exit 1
fi

export PGDATABASE=postgres

until [ "$TRIES" -gt "$TOTAL" ]; do
  echo "Checking connection ($TRIES/$TOTAL)"
  if 'psql' -c 'SELECT 1;' 1>/dev/null 2>&1; then
    FAILED=0
    break
  fi
  TRIES=$((TRIES+1))
  sleep 10
done

if [ "$FAILED" -eq "0" ]; then
  echo 'Connection to postgres is working'
else
  echo 'Connection to postgres is NOT WORKING!'
  exit 1
fi
