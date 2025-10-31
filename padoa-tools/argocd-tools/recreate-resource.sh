#!/bin/sh

set -eo pipefail


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

TIMEOUT=${TIMEOUT:-1800} # 30 minutes

# Sync with replace and force to recreate the resource
argocd app sync "$APPNAME" --resource "$RESOURCE_GROUP:$RESOURCE_KIND:$RESOURCE_NAME" --replace --force --grpc-web --timeout "$TIMEOUT"
