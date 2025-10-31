#!/bin/bash

set -e

## EXAMPLES ENV VARS
########################################
LOG_BACKUP_ENABLED="${LOG_BACKUP_ENABLED:-false}"
OVERWRITE_IF_EXISTS="${OVERWRITE_IF_EXISTS:-false}"
PROD_OVERWRITE_IS_NECESSARY="${PROD_OVERWRITE_IS_NECESSARY:-false}"
# AZURE_STORAGE_ACCOUNT="storageaccount"
# AZURE_STORAGE_CONTAINER="postgres-logs"
# AZURE_STORAGE_SAS_TOKEN="?sastokencontent"
# AZURE_BLOB_PREFIX="medical-test-client"
LOG_PATTERN="${LOG_PATTERN:-*.log}"
LOG_PATH="${LOG_PATH:-/pgdata/pg14/log}"
CLEAN_INTERVAL="${CLEAN_INTERVAL:-1800}"
AZCOPY_BUFFER_GB="${AZCOPY_BUFFER_GB:-0.001}" # 1MB
########################################

### Wait for "/pgdata/pg14/log" directory to be created

while [ ! -d "$LOG_PATH" ]; do
    echo "Folder $LOG_PATH does not exist yet. Keep waiting..."
    sleep 10
done
echo "Folder $LOG_PATH exists. Continuing..."


if [[ -z "$CLUSTER_ENV" ]]; then
    echo 'Please set CLUSTER_ENV!'
    exit 1
fi

if [[ "$CLUSTER_ENV" = 'prod' ]] && [[ "$OVERWRITE_IF_EXISTS" = 'true' ]] && [[ "$PROD_OVERWRITE_IS_NECESSARY" = 'false' ]]; then
    echo 'I refuse to overwrite prod logs!'
    exit 1
fi

upload_file() {
  filepath="$1"
  filename=$(basename "$filepath")

  azcopy copy "--overwrite=$OVERWRITE_IF_EXISTS" "$filepath" "https://${AZURE_STORAGE_ACCOUNT}.blob.core.windows.net/${AZURE_STORAGE_CONTAINER}/$AZURE_BLOB_PREFIX/$HOSTNAME/${filename}${AZURE_STORAGE_SAS_TOKEN}"
}

while true; do
    # Delete logs files without any modification for more than 3 hours
    FILES_TO_DELETE=$(find "$LOG_PATH" -name "$LOG_PATTERN" -mmin +180)
    for FILE in $FILES_TO_DELETE; do
        # Backup before deletion if BACKUP_ENABLED
        if $LOG_BACKUP_ENABLED; then
            echo "Uploading file $FILE"
            upload_file "$FILE" || (echo "Failed to upload file $FILE" && continue)
            echo "Upload finished"
        fi
        echo "Deleting file $FILE"
        rm -f "$FILE"
    done
    sleep "$CLEAN_INTERVAL"
done
