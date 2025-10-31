#!/bin/sh
set -e

if [ -z "$UNIQUE_ID" ] ;
then
  echo "[ERROR] You must specify the workflowId"
  exit 1
fi

# See https://access.crunchydata.com/documentation/postgres-operator/latest/architecture/user-management#custom-passwords

kubectl patch secret -n "cs-$UNIQUE_ID" "cs-$UNIQUE_ID-pguser-e2e" -p \
   '{"stringData":{"password":"e2epadoa123","verifier":""}}'

