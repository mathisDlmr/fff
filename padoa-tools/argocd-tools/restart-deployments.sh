#!/bin/sh

set -eo pipefail


if [ -z "$APPNAME" ]; then
    echo "Please provide an application to delete through APPNAME varenv"
    exit 1
fi
if [ -z "$ARGOCD_SERVER" ]; then
    echo "please provide an argocd-server host through argocd_server varenv"
    exit 1
fi

# Restart all deployments in  application APPNAME
argocd app actions run "$APPNAME" restart --kind Deployment --all --server "$ARGOCD_SERVER" --grpc-web
