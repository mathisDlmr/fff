#!/bin/sh
if [ -z "$DUMP_NAME" ]; then
  echo "No dump provided"
  exit 1
fi

if [ -z "$INIT_DATA_DUMPS_STORAGE_SAS_TOKEN" ]; then
  echo "No init-data dumps token provided"
  exit 1
fi

COMPRESSED_DUMP_NAME="$DUMP_NAME.xz"

# We call the runFinished endpoint and check every 30 seconds if the run is over
TIMEOUT=40

# check for existing dump

dumpExists=false

checkDumpExists(){
  dumpExists=$(az storage blob exists -c "dumps"  --account-name "padoastginitdata" --name "${COMPRESSED_DUMP_NAME}" --sas-token "${INIT_DATA_DUMPS_STORAGE_SAS_TOKEN}" | jq .exists)
}


checkDumpExists # Call the API a first time

# Wait 20 min for dump
for count in `seq 1 ${TIMEOUT}`; do
  if [ "$dumpExists" = true ]; then
    echo "Dump found"
    exit 0
  else
    echo "Dump does not exists yet"
    sleep 30
    checkDumpExists
  fi
done

exit 1