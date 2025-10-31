#!/bin/sh

# 180 x 10 (sleep duration) = 30min max
TIMEOUT=180

for count in $(seq 1 ${TIMEOUT}); do
  if ! kubectl get cm db-is-ready ; then
    echo "[INFO] CM db-is-ready does not exists yet"
    sleep 10
  else
    echo "[INFO] CM db-is-ready is available"
    exit 0
  fi
done


echo "[ERROR] CM db-is-ready was not found, something went wrong in the database setup"
exit 1
