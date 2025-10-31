#!/bin/sh

# Usage :
# This script exits 0 if the provided E2E run is over and successful
# Or it exits 1 if the provided E2E run is over and needs to retry some tests

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

echo "[DEBUG] Determining if we need to retry tests avec run : $BUILD_ID"

isRunFinished=false
isRunSuccesful=false

callRunFinished(){
  isRunFinished=$(curl ${INTEGRATOR_ENDPOINT}/sorrycypress/runFinished\?branch\=${BRANCH_NAME}\&ciBuildId\=${BUILD_ID} | jq .success)
}

callRunSuccessful(){
  isRunSuccesful=$(curl ${INTEGRATOR_ENDPOINT}/sorrycypress/runSuccess\?branch\=${BRANCH_NAME}\&ciBuildId\=${BUILD_ID})
}

# We call the runFinished endpoint and check every 30 seconds if the run is over
callRunFinished # Call the API a first time

while [ "$isRunFinished" != "true" ]
do
  echo "Run is still Running"
  sleep 30
  callRunFinished
done

echo "[DEBUG] The value if isRunFinished is : $isRunFinished"

while [ "$isRunSuccesful" != "true" ]
do
  callRunSuccessful
  echo "[DEBUG] Content of isRunSuccesful is : $isRunSuccesful"
  if [ $(echo $isRunSuccesful | grep success) ]
  then
    echo "[INFO] Looking for status"
    if [ $(echo $isRunSuccesful | grep true) ]
    then
       echo "[INFO] Run is successful"
       exit 0
    else
      echo "[INFO] Run is not successful"
      exit 1
    fi
  else
    echo "[DEBUG] There was an error with the return content, checking again in 10s"
    sleep 30
  fi

done
