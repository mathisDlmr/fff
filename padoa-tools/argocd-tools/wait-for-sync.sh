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

TIMEOUT=${TIMEOUT:-7200} # 2 hours

# Wait until the application becomes healthy
argocd app wait "$APPNAME" --health --grpc-web --timeout "$TIMEOUT"
