#!/bin/bash

if [[ -n "$FAKETIME" ]]; then
    if [[ -z "$TZ" ]]; then
        TZ="Europe/Paris"
        export TZ
    fi
    echo "FAKETIME: $FAKETIME"
    if [[ -n $FAKETIME_HOURS_NAME ]] && [[ -f /tmp/workspace/test/hours.env ]]; then
      echo "FAKETIME_HOURS_NAME is set and file /tpm/workspace/test/hours.env exists" 
      source /tmp/workspace/test/hours.env
      hours="${!FAKETIME_HOURS_NAME}"
    else
        echo "FAKETIME_HOURS_NAME is not set or file /tpm/workspace/test/hours.env does not exist"
        hours="+$(( ($(date --date "$FAKETIME" +%s) - $(date +%s) )/(60*60) ))h"
    fi
    echo "Hours: $hours"
    exec faketime -f "$hours" "$@"
else
    exec "$@"
fi
