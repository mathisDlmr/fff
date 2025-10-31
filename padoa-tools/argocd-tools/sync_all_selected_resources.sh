#!/bin/sh

# $1 : application name in which the resources are sync
# $2 : server address
# $3 : group of the resource
# $4 : kind of the resource

app_name=$1
server=$2
group=$3
kind=$4

resources=$(argocd app get $app_name --server $server --grpc-web -o json | jq ".status.resources | .[] | select (.kind == \"$kind\") | .name" | tr -d '\"' | tr '\n' ' ')

command_resources=" "


for resource in $resources
do
  command_resources="${command_resources}--resource $group:$kind:$resource "
done

argocd app sync $app_name --server $server --grpc-web --retry-limit 10 ${command_resources}