#!/bin/sh

# See : https://www.notion.so/padoa/Format-des-m-triques-Prom-des-E2E-1d74976cdfac804c9f0bda07bbd843f0?pvs=4

if [ -z "$PUSHGATEWAY_URL" ] ;
then
  echo "[ERROR] You must specify the PUSHGATEWAY_URL"
  exit 1
fi

if [ -z "$PUSHGATEWAY_USER" ] ;
then
  echo "[ERROR] You must specify the PUSHGATEWAY_USER"
  exit 1
fi

if [ -z "$PUSHGATEWAY_PASSWORD" ] ;
then
  echo "[ERROR] You must specify the PUSHGATEWAY_PASSWORD"
  exit 1
fi

if [ -z "$RUN_ID" ] ;
then
  echo "[ERROR] You must specify the RUN_ID"
  exit 1
fi

if [ -z "$METRIC_NAME" ] ;
then
  echo "[ERROR] You must specify the METRIC_NAME"
  exit 1
fi

if [ -z "$METRIC_VALUE" ] ;
then
  echo "[ERROR] You must specify the METRIC_VALUE"
  exit 1
fi

if [ -z "$MS_NAME" ] ;
then
  echo "[ERROR] You must specify the MS_NAME"
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

echo "[INFO] Sending metric to pushgateway..."

metricsPayload="$METRIC_NAME{msName=\"$MS_NAME\",runid=\"$RUN_ID\",runType=\"$RUN_TYPE\",branchName=\"$BRANCH_NAME\"} $METRIC_VALUE"

echo "[INFO] Pushing metric : $metricsPayload"

pushgatewayCompleteUrl="$PUSHGATEWAY_URL/metrics/job/e2e_sli/instance/$RUN_ID"
echo "$pushgatewayCompleteUrl"
echo "$metricsPayload" | curl -u "$PUSHGATEWAY_USER":"$PUSHGATEWAY_PASSWORD" --data-binary @- "$pushgatewayCompleteUrl"

