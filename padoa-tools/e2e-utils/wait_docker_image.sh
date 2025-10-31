#!/bin/sh

set -e

TIMEOUT=40

if [ -z "$TAG" ]; then
  echo "No tag provided"
  exit 1
fi

if [ -z "$REPOSITORY" ]; then
  echo "No repository dumps token provided"
  exit 1
fi

az login --identity

for count in $(seq 1 ${TIMEOUT}); do
  if ! az acr repository show --name padoa --image "$REPOSITORY":"$TAG" ; then
    echo "Waiting for image $REPOSITORY:$TAG to be available..."
    sleep 30
  else
    echo "Docker image $REPOSITORY:$TAG available !"
    exit 0
  fi
done


echo "L'image Docker $REPOSITORY:$TAG n'est pas disponible ! "
echo "Vérifiez que le build du commit $TAG s'est bien déroulé sur CircleCI !"

exit 1
