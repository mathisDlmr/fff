#!/bin/bash

if [[ -n $FAKETIME ]]
then
  if [[ -z $TZ ]]
  then
    TZ="Europe/Paris"
    export TZ
  fi
  echo "FAKETIME=$FAKETIME"
  # Difference in hours between the current date and the FAKETIME date
  hours="+$(( ($(date --date "$FAKETIME" +%s) - $(date +%s) )/(60*60) ))h"
  echo "hours=$hours"

  export LD_PRELOAD=/usr/local/lib/faketime/libfaketime.so.1
  export FAKETIME="$hours"
  export FAKETIME_DONT_FAKE_MONOTONIC=1
  export FAKETIME_DONT_RESET=1 
  export FAKETIME_NO_CACHE=1
  
  $@
else
  echo "FAKETIME not set"
  $@
fi
