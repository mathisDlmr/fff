#!/bin/sh
set +eo pipefail

TRIES=${TRIES:-1}
TOTAL=${TOTAL:-18} # 18 x 10 secs = 3min

if [ -z "$TEMPLATE_NAME" ]; then
    echo "Please provide a template to look for"
    exit 1
fi

getResource() {
  argo template get "$TEMPLATE_NAME"
}


resourceStatus=$(getResource)

echo "Resource status: $resourceStatus"
if ! ([[ -z "$resourceStatus" ]] || [[ "$resourceStatus" == 'null' ]]) ; then
  echo '[INFO] Ressource exists'
else
  echo 'Resource does not exist, waiting'
fi

until [ "$TRIES" -gt "$TOTAL" ]; do
  echo "Checking status ($TRIES/$TOTAL)"
  resourceStatus=$(getResource)
  if ! ([[ -z "$resourceStatus" ]] || [[ "$resourceStatus" == 'null' ]]); then
    echo "Resource exist, all good"
    exit 0
  fi
  TRIES=$((TRIES+1))
  sleep 10
done

exit 1
