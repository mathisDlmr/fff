#!/bin/bash

set -e

echo_green() {
  GREEN='\033[0;32m'
  NC='\033[0m' # No Color
  printf "$GREEN$*$NC\n\n"
}

# Env Vars required for Azure Blob Container authorized access
export AZURE_STORAGE_ACCOUNT="${AZURE_STORAGE_ACCOUNT:-padoadevkubecost}"
export AZURE_STORAGE_CONTAINER="${AZURE_STORAGE_CONTAINER:-kubecost}"
export AZURE_STORAGE_SAS_TOKEN="$AZURE_STORAGE_SAS_TOKEN"

CURRENT_DATE=$(date +%Y%m%d)
DAYS_TO_SUBSTRACT=${DAYS_TO_SUBSTRACT:-0}
# Can't use date binary to sutract because the image is an alpine
DATE=$(python3 - <<END
from datetime import datetime, timedelta

current_date = datetime.strptime('$CURRENT_DATE', '%Y%m%d')
new_date = current_date - timedelta(days=$DAYS_TO_SUBSTRACT)
print(new_date.strftime('%Y%m%d'))
END
)

echo $DATE;
#DATE="$(date -j -v-${DAYS_TO_SUBSTRACT}d +%Y%m%d)"

CLUSTER="${CLUSTER}"
KUBECOST_URL="${KUBECOST_URL}"
WINDOW="${WINDOW:-7d}"
AZURE_BLOB_PREFIX="kubecost/AllocationExport/$DATE"
FILENAME="$CLUSTER-$DATE.csv"

echo_green "Downloading csv file..."
# Doc : https://docs.kubecost.com/apis/apis-overview/api-allocation
curl -o "$FILENAME" "$KUBECOST_URL/model/allocation" \
     -d window="$WINDOW" \
     -d idle=true \
     -d resolution=60m \
     -d aggregate=namespace \
     -d accumulate=true \
     -d format=csv \
     -G

echo_green "Cleaning csv file (removing json payload if present)..."
sed -i -E '/^\{"code":/d' "$FILENAME"

echo_green "Uploading csv file to Azure Blob Container..."
az storage blob upload \
   -f "./$FILENAME" \
   -c "$AZURE_STORAGE_CONTAINER" \
   -n "$AZURE_BLOB_PREFIX/$FILENAME" \
   --overwrite true
