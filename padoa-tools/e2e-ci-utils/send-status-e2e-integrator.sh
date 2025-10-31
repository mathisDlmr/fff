#!/bin/sh

# See : https://www.notion.so/padoa/Format-des-m-triques-Prom-des-E2E-1d74976cdfac804c9f0bda07bbd843f0?pvs=4

INTEGRATOR_ENDPOINT="https://e2e-integrator.aodap-staging.fr"

if [ -z "$INTEGRATOR_ENDPOINT" ]
then
  echo "[ERROR] INTEGRATOR_ENDPOINT is missing"
  exit 1
fi

if [ -z "$RUN_TYPE" ] ;
then
  echo "[ERROR] You must specify the RUN_TYPE"
  exit 1
fi

if [ -z "$BRANCH_NAME" ] ;
then
  echo "[ERROR] You must specify the BRANCH_NAME"
  exit 1
fi

if [ -z "$MS_NAME" ] ;
then
  echo "[ERROR] You must specify the MS_NAME"
  exit 1
fi

if [ -z "$RUN_ID" ] ;
then
  echo "[ERROR] You must specify the RUN_ID"
  exit 1
fi

if [ -z "$STATUS" ] ;
then
  echo "[ERROR] You must specify the STATUS"
  exit 1
fi

if [ -z "$PR_LINK" ] ;
then
  echo "[ERROR] You must specify the PR_LINK"
  exit 1
fi

if [ -z "$MESSAGE" ] ;
then
  echo "[ERROR] You must specify the MESSAGE"
  exit 1
fi

echo "[INFO] Sending status to e2e-integrator..."

statusPayload="{
  \"msName\":\"$MS_NAME\",
  \"runType\":\"$RUN_TYPE\",
  \"branchName\":\"$BRANCH_NAME\",
  \"uniqueId\":\"$RUN_ID\",
  \"status\":\"$STATUS\",
  \"prLink\":\"$PR_LINK\",
  \"message\":\"$MESSAGE\"
}"

echo "[INFO] Pushing status : $statusPayload"

echo "$statusPayload" | curl -v \
  --header "Content-Type: application/json" \
  --data-binary @- "${INTEGRATOR_ENDPOINT}/runstatus"
