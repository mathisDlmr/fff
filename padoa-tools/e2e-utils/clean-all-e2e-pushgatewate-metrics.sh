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

echo "[INFO] Deleting all e2e_sli metrics from pushgateway..."

pushgatewayCompleteUrl="$PUSHGATEWAY_URL/metrics/job/e2e_sli"

INSTANCE_IDS=$(curl -X GET -u "$PUSHGATEWAY_USER":"$PUSHGATEWAY_PASSWORD" "https://pushgateway.aodap-staging.fr/api/v1/metrics" | jq '.data[].labels | select(.job=="e2e_sli")' | jq -r '.instance')

while IFS= read -r line; do
  echo "[INFO] Deleting job e2e_sli for instance : $line"
  # Deleting job that only have the label instance
  curl -X DELETE -u "$PUSHGATEWAY_USER":"$PUSHGATEWAY_PASSWORD" "$pushgatewayCompleteUrl/instance/$line"
  # Deleting job that only have the label instance and runid
  curl -X DELETE -u "$PUSHGATEWAY_USER":"$PUSHGATEWAY_PASSWORD" "$pushgatewayCompleteUrl/instance/$line/runid/$line"
done << EOF
${INSTANCE_IDS}
EOF
