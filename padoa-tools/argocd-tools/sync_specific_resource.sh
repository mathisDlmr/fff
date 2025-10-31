#!/bin/sh

# $1 : application name in which the resources are sync
# $2 : server address
# $3 : group of the resource
# $4 : kind of the resource
# $5 : name of the resource
#
# Optional settings:
# WAIT_FOR_RESOURCE: wait for the resource after syncing it

set -eo pipefail
set -x # For debug

app_name=$1
server=$2
group=$3
kind=$4
resource=$5

WAIT_FOR_RESOURCE=${WAIT_FOR_RESOURCE:=false}

argocd app sync "$app_name" --server "$server" --grpc-web --retry-limit 10 --resource "$group:$kind:$resource"

if $WAIT_FOR_RESOURCE; then
    argocd app wait --sync "$app_name" --server "$server" --grpc-web --resource "$group:$kind:$resource" --timeout 10
fi
