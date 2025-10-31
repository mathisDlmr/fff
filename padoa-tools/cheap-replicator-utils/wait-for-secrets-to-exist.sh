#!/bin/sh

if [ -z "$NAMESPACE" ] ;
then
  echo "[ERROR] You must specify the NAMESPACE"
  exit 1
fi

if [ -z "$MAX_WAIT_TIME" ] ;
then
  echo "[ERROR] You must specify the MAX_WAIT_TIME"
  exit 1
fi

COUNT=0

echo $@

for secret in "$@"
do
  DONE=1
  while [ "$DONE" -ne 0 ] && [ "$COUNT" -lt "$MAX_WAIT_TIME" ]
  do
    echo "[+] Looking for secret $secret"
    kubectl -n "$NAMESPACE" get secret -o name | grep secret/"$secret"
    DONE=$?
    COUNT=$((COUNT+1))
    if [ "$DONE" -ne 0 ]
    then
      echo "[-] Secret $secret does not exist yet, retrying in 30 seconds"
      sleep 30
    else
      echo "[+] Secret $secret found"
    fi
  done
done

if [ "$COUNT" -eq "$MAX_WAIT_TIME" ]
then
  echo "[ERROR] MAX_WAIT_NUMBER of $MAX_WAIT_TIME reached - secret(s) not founds"
  exit 1
else
  echo "[+] All secrets found"
  exit 0
fi
