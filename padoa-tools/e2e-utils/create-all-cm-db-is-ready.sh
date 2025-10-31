#!/bin/sh

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

set +e

TOTAL_RUNNER=$(( $TOTAL_RUNNER - 1))
NB_RUNNER="0"

while [ $NB_RUNNER -le $TOTAL_RUNNER ]; do
  TRIES=5
  echo "[INFO] Creating CM in namespace $UNIQUE_ID-${NB_RUNNER}"
  kubectl -n $UNIQUE_ID-${NB_RUNNER} create cm db-is-ready --dry-run=client -o yaml | kubectl apply -f -

  for count in $(seq 1 ${TRIES}); do
    if ! kubectl -n $UNIQUE_ID-${NB_RUNNER} get cm db-is-ready ; then
      echo "[INFO] CM db-is-ready was not found, creating it again"
      kubectl -n $UNIQUE_ID-${NB_RUNNER} create cm db-is-ready --dry-run=client -o yaml | kubectl apply -f -
      sleep 10
    else
      echo "[INFO] CM Already exists"
      break
    fi
  done

  NB_RUNNER=$(( $NB_RUNNER + 1 ))

done

