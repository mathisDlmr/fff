#!/bin/bash

if [[ -n $FAKETIME ]]
then
    if [[ -z $TZ ]]
    then
        TZ="Europe/Paris"
        export TZ
    fi
    echo "FAKETIME=$FAKETIME"
    hours="+$(( ($(date --date "$FAKETIME" +%s) - $(date +%s) )/(60*60) ))h"
    echo "hours=$hours"
    faketime -f "$hours" $@
else
    echo "FAKETIME not set"
    $@
fi
