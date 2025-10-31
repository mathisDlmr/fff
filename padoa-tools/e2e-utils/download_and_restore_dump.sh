#!/bin/sh

set -e

# Dump name
if [ -z "$DUMP_NAME" ]; then
  echo "[ERROR] No dump provided"
  exit 1
fi

if [ -z "$INIT_DATA_DUMPS_STORAGE_ENDPOINT" ]; then
  echo "[ERROR] Missing endpoint"
  exit 1
fi
if [ -z "$INIT_DATA_DUMPS_STORAGE_CONTAINER" ]; then
  echo "[ERROR] Missing container"
  exit 1
fi
if [ -z "$INIT_DATA_DUMPS_STORAGE_SAS_TOKEN" ]; then
  echo "[ERROR] Missing sas token"
  exit 1
fi

COMPRESSED_DUMP_NAME="$DUMP_NAME.xz"
# Download
az storage blob download -f "$COMPRESSED_DUMP_NAME" --blob-url "$INIT_DATA_DUMPS_STORAGE_ENDPOINT""$INIT_DATA_DUMPS_STORAGE_CONTAINER"/"$COMPRESSED_DUMP_NAME""$INIT_DATA_DUMPS_STORAGE_SAS_TOKEN"
# Decompression
xz -d "$COMPRESSED_DUMP_NAME"

echo "[INFO] Dropping database postgres"
psql -e -v ON_ERROR_STOP=1 -d postgres <<EOF
  SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '0_wellinjob';
  SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '0_wellinjob-template';
  DROP DATABASE IF EXISTS "0_wellinjob-template";
  CREATE DATABASE "0_wellinjob-template" OWNER owner;
EOF

echo "[INFO] Restoring dump to database 0_wellinjob-template"
psql -d 0_wellinjob-template < "$DUMP_NAME"
