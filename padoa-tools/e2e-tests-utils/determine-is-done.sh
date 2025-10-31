#!/bin/sh

# Usage :
# This script exits 0 if the provided E2E run is over

if [ -z "$INTEGRATOR_ENDPOINT" ]
then
  echo "[ERROR] INTEGRATOR_ENDPOINT is missing"
  exit 1
fi

if [ -z "$BRANCH_NAME" ]
then
  echo "[ERROR] BRANCH_NAME is missing"
  exit 1
fi

if [ -z "$BUILD_ID" ]
then
  echo "[ERROR] BUILD_ID is missing"
  exit 1
fi

isRunFinished=false

callRunFinished(){
  isRunFinished=$(curl ${INTEGRATOR_ENDPOINT}/sorrycypress/runFinished\?branch\=${BRANCH_NAME}\&ciBuildId\=${BUILD_ID} | jq .success)
}

# We call the runFinished endpoint and check every 30 seconds if the run is over
callRunFinished # Call the API a first time

while [ $isRunFinished = false ]
do
  echo "Run is still Running"
  sleep 60
  callRunFinished
done

exit 0
