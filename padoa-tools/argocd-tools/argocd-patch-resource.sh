#!/bin/bash
#
#
# RESOURCE_GROUP MUST NOT contain the part after /
# postgres-operator.crunchydata.com/v1beta1 becomes
# postgres-operator.crunchydata.com

set -eo pipefail

if [ -z "$ARGOCD_SERVER" ]; then
    echo "please provide an argocd-server host through ARGOCD_SERVER varenv"
    exit 1
fi
if [ -z "$APPNAME" ]; then
    echo "Please provide an application that container the resource to be deleted through APPNAME varenv"
    exit 1
fi
if [ -z "$RESOURCE_NAME" ]; then
    echo "Please provide the resource name through RESOURCE_NAME varenv"
    exit 1
fi
if [ -z "$RESOURCE_GROUP" ]; then
    echo "Please provide the resource name through RESOURCE_GROUP varenv"
    exit 1
fi
if [ -z "$RESOURCE_KIND" ]; then
    echo "Please provide the resource kind through RESOURCE_KIND varenv"
    exit 1
fi
if [ -z "$PATCH" ]; then
    echo "Please provide the resource kind through PATCH varenv"
    exit 1
fi

TIMEOUT=${TIMEOUT:-900}

argocd app patch-resource "$APPNAME"\
  --grpc-web \
  --group "$RESOURCE_GROUP" \
  --kind "$RESOURCE_KIND" \
  --resource-name "$RESOURCE_NAME" \
  --patch "$PATCH"
