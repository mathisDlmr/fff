#!/bin/sh

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

if [ -z "$CLUSTER_AFFECTED" ] ;
then
  echo "[ERROR] You must specify the CLUSTER_AFFECTED"
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

echo "[INFO] Sending metric to pushgateway..."

metricsPayload="$METRIC_NAME{cluster=\"$CLUSTER\"} $METRIC_VALUE"

echo "[INFO] Pushing metric : $metricsPayload"

pushgatewayCompleteUrl="$PUSHGATEWAY_URL/metrics/job/e2e_sli/instance/$CLUSTER"
echo "$pushgatewayCompleteUrl"
echo "$metricsPayload" | curl -u "$PUSHGATEWAY_USER":"$PUSHGATEWAY_PASSWORD" --data-binary @- "$pushgatewayCompleteUrl"

