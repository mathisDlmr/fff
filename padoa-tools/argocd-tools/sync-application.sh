#!/bin/sh

set -eo pipefail


if [ -z "$APPNAME" ]; then
    echo "Please provide the name of the application that will be synced through APPNAME varenv"
    exit 1
fi
if [ -z "$ARGOCD_SERVER" ]; then
    echo "please provide an argocd-server host through argocd_server varenv"
    exit 1
fi

TIMEOUT=${TIMEOUT:-1800} # 30 minutes
ASYNC=${ASYNC:-false}

argocd app sync "$APPNAME" --grpc-web --timeout "$TIMEOUT" --async="$ASYNC"
