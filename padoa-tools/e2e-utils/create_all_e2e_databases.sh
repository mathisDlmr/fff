#!/bin/sh
set -e

if [ -z "$TOTAL_RUNNER" ] ;
then
  echo "[ERROR] You must specify the total runner"
  exit 1
fi

if [ -z "$UNIQUE_ID" ] ;
then
  echo "[ERROR] You must specify the workflowId"
  exit 1
fi

TOTAL_RUNNER=$(( $TOTAL_RUNNER - 1))

# We create only the wellinjob database for the first runner
echo "[INFO] Creating database 0_wellinjob"
    psql -e -v ON_ERROR_STOP=1 -d postgres <<EOF
  SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '0_wellinjob-template';
  SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$PGDATABASE';
  ALTER DATABASE "0_wellinjob" WITH ALLOW_CONNECTIONS false;
  SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '0_wellinjob';
  DROP DATABASE IF EXISTS "0_wellinjob";
  CREATE DATABASE "0_wellinjob" OWNER owner TEMPLATE "0_wellinjob-template";

EOF

# Then, for all runner except the first, we create the wellinjob and the wellinjob-template database
NB_RUNNER="1"
while [ $NB_RUNNER -le $TOTAL_RUNNER ]; do
  WJ_PGDATABASE=${NB_RUNNER}"_wellinjob"
  PGDATABASE=${NB_RUNNER}"_wellinjob-template"
  IS_READY_DATABASE="$UNIQUE_ID-${NB_RUNNER}_is_ready"

    echo "[INFO] Creating database $PGDATABASE"
    psql -e -v ON_ERROR_STOP=1 -d postgres <<EOF
  SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '0_wellinjob-template';
  SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$PGDATABASE';
  ALTER DATABASE "$WJ_PGDATABASE" WITH ALLOW_CONNECTIONS false;
  SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$WJ_PGDATABASE';
  DROP DATABASE IF EXISTS "$WJ_PGDATABASE";
  CREATE DATABASE "$WJ_PGDATABASE" OWNER owner TEMPLATE "0_wellinjob-template";
  DROP DATABASE IF EXISTS "$PGDATABASE";
  CREATE DATABASE "$PGDATABASE" OWNER owner TEMPLATE "0_wellinjob-template";

EOF
  NB_RUNNER=$(( $NB_RUNNER + 1 ))
done

