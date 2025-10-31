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

APPOWNER=${APPOWNER:-$(echo $APPNAME | cut -d '.' -f 1)}

# Delete applicaton APPNAME
argocd app delete "$APPNAME" --server "$ARGOCD_SERVER" --grpc-web -y

if $WAIT_FOR_DELETION; then
    while true; do
        APP_INFO=$(argocd app list --server $ARGOCD_SERVER --grpc-web -o json -l "argocd.argoproj.io/instance=$APPOWNER")
        echo "[INFO] APP_INFO :"
        echo $APP_INFO
        APP_EXISTS=$(jq -r ".[] | select(.metadata.name == \"$APPNAME\") | .metadata.deletionTimestamp // empty"  <<< "$APP_INFO" )
        sleep 5
        [ ! -z "$APP_EXISTS" ] || break
        echo "Waiting for application '$APPNAME' to be deleted..." && sleep 10
    done
fi
