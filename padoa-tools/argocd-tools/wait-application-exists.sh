#!/bin/sh
# This scripts wait for an argocd application to have a health status

# WARNING ## WARNING ## WARNING ## WARNING ## WARNING #

# It does not tell you if the application is healthy or not, just that it is created

# WARNING ## WARNING ## WARNING ## WARNING ## WARNING #
set -eo pipefail

TRIES=${TRIES:-1}
TOTAL=${TOTAL:-360}

if [ -z "$APPNAME" ]; then
    echo "Please provide an application to check if it exists through APPNAME varenv"
    exit 1
fi
if [ -z "$ARGOCD_SERVER" ]; then
    echo "please provide an argocd-server host through argocd_server varenv"
    exit 1
fi

getResourceStatus() {
  argocd app get "$APPNAME" --grpc-web -o json | jq -r ".status.health.status"
}


resourceStatus=$(getResourceStatus)

echo "Resource status: $resourceStatus"
if ! ([[ -z "$resourceStatus" ]] || [[ "$resourceStatus" == 'null' ]]) ; then
  echo '[INFO] Ressource exists'
else
  echo 'Resource does not exist, waiting'
fi

until [ "$TRIES" -gt "$TOTAL" ]; do
  echo "Checking status ($TRIES/$TOTAL)"
  resourceStatus=$(getResourceStatus)
  echo "Status: $resourceStatus"
  if ! ([[ -z "$resourceStatus" ]] || [[ "$resourceStatus" == 'null' ]]); then
    echo "Resource exist, all good"
    exit 0
  fi
  TRIES=$((TRIES+1))
  sleep 10
done

exit 1