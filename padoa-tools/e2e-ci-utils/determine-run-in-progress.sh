#!/bin/sh

# Usage :
# This script exits 0 if the provided E2E run exists
# Or it exits 1 if the provided E2E run does not exists

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

echo "[DEBUG] Determining if the run with ID $BUILD_ID exists"

isRunExists=false

callRunExists(){
  isRunExists=$(curl ${INTEGRATOR_ENDPOINT}/sorrycypress/runInProgress\?branch\=${BRANCH_NAME}\&ciBuildId\=${BUILD_ID})
}

# Init try
callRunExists

TRIES=${TRIES:-45} # Default 45 times
SLEEP_TIME=${TRIES:-60} # default 60s
EXITCODE_EXISTS=${EXITCODE_EXISTS:-0} # Allow to change the exit code of the script
EXITCODE_NOT_EXISTS=${EXITCODE_NOT_EXISTS:-1} # Allow to change the exit code of the script

for count in $(seq 1 ${TRIES}); do
  echo "[INFO] Looking for status of run $BUILD_ID"
  if [ $(echo $isRunExists | grep true) ]
  then
      echo "[INFO] Run in progress"
      exit ${EXITCODE_EXISTS}
  else
    echo "[INFO] No run in progress, waiting for ${SLEEP_TIME}s before retrying"
    sleep ${SLEEP_TIME}
  fi
  callRunExists
done

exit ${EXITCODE_NOT_EXISTS}
