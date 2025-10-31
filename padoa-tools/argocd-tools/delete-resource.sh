#!/bin/sh

set -eo pipefail

TRIES=${TRIES:-1}
TOTAL=${TOTAL:-60}
FAILED=${FAILED:-1}

if [ -z "$APPNAME" ]; then
    echo "Please provide an application that container the resource to be deleted through APPNAME varenv"
    exit 1
fi
if [ -z "$ARGOCD_SERVER" ]; then
    echo "please provide an argocd-server host through argocd_server varenv"
    exit 1
fi
if [ -z "$RESOURCE_NAME" ]; then
    echo "Please provide the resource name through RESOURCE_NAME varenv"
    exit 1
fi
if [ -z "$RESOURCE_KIND" ]; then
    echo "Please provide the resource kind through RESOURCE_KIND varenv"
    exit 1
fi

getResourceStatus() {
  argocd app get "$APPNAME" --grpc-web -o json | jq -r ".status.resources[] | select(.kind == \"$RESOURCE_KIND\" and .name == \"$RESOURCE_NAME\").health.status"
}

resourceExists() {
  [[ "$1" != 'Missing' ]]
}

resourceStatus=$(getResourceStatus)
echo "Resource status: $resourceStatus"
if resourceExists "$resourceStatus"; then
  echo 'Deleting resource...'
  argocd app delete-resource "$APPNAME" \
    --grpc-web \
    --kind "$RESOURCE_KIND" \
    --resource-name "$RESOURCE_NAME"
else
  echo 'Resource does not exist, skipping deletion'
fi

until [ "$TRIES" -gt "$TOTAL" ]; do
  echo "Checking status ($TRIES/$TOTAL)"
  resourceStatus=$(getResourceStatus)
  echo "Status: $resourceStatus"
  if ! resourceExists "$resourceStatus"; then
    FAILED=0
    echo "Resource does not exist, sucessful deletion."
    exit 0
  fi
  TRIES=$((TRIES+1))
  sleep 5
done

exit 1
